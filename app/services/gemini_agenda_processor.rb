require "tempfile"
require "json"

# GeminiAgendaProcessor uploads a council meeting's agenda PDF to the Gemini
# Files API, prompts Gemini to extract housing appeals, then creates
# AgendaItem and HousingAppeal records from the structured JSON response.
#
# Usage:
#   processor = GeminiAgendaProcessor.new(council_meeting)
#   appeals = processor.process   # => Array of HousingAppeal records
class GeminiAgendaProcessor
  MODEL = "gemini-3-flash-preview"

  PROMPT = <<~PROMPT
    You are analyzing a city council meeting agenda PDF.

    Your task: extract every housing project appeal on this agenda.

    For each appeal found, return a JSON object in the following array format.
    If no appeals are found, return an empty array [].

    Return ONLY valid JSON — no markdown, no explanation, just the array.

    Schema for each appeal object:
    {
      "item_number": <integer or null>,
      "title": "<short agenda item title>",
      "description": "<full text of the agenda item>",
      "appeal_description": "<2-4 sentence plain-English summary: what is being appealed, who is appealing, and the main grounds. Write this for a general audience with no technical jargon>",
      "project_name": "<name of the housing project, or null>",
      "project_address": "<street address, or null>",
      "apn": "<Assessor Parcel Number, or null>",
      "appellant_name": "<name of appellant(s), or null>",
      "grounds_category": "<one of: CEQA, design_review, use_permit, neighborhood_impact, procedural, other>",
      "grounds_description": "<summary of the grounds for appeal>",
      "reference_number": "<city-assigned case or file number, or null>"
    }
  PROMPT

  def initialize(meeting)
    @meeting = meeting
    @client = Google::Genai::Client.new
  end

  # Processes the meeting's agenda PDF through Gemini.
  # Creates AgendaItem and HousingAppeal records for each appeal found.
  # Returns the array of HousingAppeal records created (may be empty if no appeals).
  def process
    raise "No PDF attached to meeting #{@meeting.id}" unless @meeting.agenda_pdf.attached?

    pdf_file = upload_pdf_to_gemini
    appeals_data = extract_appeals_from_gemini(pdf_file)
    records = persist_appeals(appeals_data)

    # Clean up the uploaded file from Gemini's servers (they expire in 48h anyway)
    @client.files.delete(name: pdf_file.name) rescue nil

    records
  ensure
    @temp_file&.close
    @temp_file&.unlink
  end

  private

  def city
    @meeting.agenda_source.city
  end

  # Downloads the PDF from ActiveStorage to a temp file and uploads to Gemini Files API.
  def upload_pdf_to_gemini
    @temp_file = Tempfile.new([ "agenda_#{@meeting.id}", ".pdf" ])
    @temp_file.binmode
    @temp_file.write(@meeting.agenda_pdf.download)
    @temp_file.flush

    Rails.logger.info "[GeminiAgendaProcessor] Uploading PDF for #{city.name} meeting #{@meeting.meeting_date}"

    @client.files.upload(
      file: @temp_file.path,
      config: {
        mime_type: "application/pdf",
        display_name: "#{city.name} Agenda #{@meeting.meeting_date}"
      }
    )
  end

  # Sends the uploaded file + prompt to Gemini and returns parsed array of appeal hashes.
  def extract_appeals_from_gemini(pdf_file)
    Rails.logger.info "[GeminiAgendaProcessor] Extracting appeals via Gemini for #{city.name} #{@meeting.meeting_date}"

    response = @client.models.generate_content(
      model: MODEL,
      contents: [ pdf_file, PROMPT ]
    )

    raw = response.text.strip
    # Strip markdown code fences if the model wraps the JSON anyway
    raw = raw.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip

    JSON.parse(raw)
  rescue JSON::ParserError => e
    Rails.logger.error "[GeminiAgendaProcessor] JSON parse failed for #{city.name} #{@meeting.meeting_date}: #{e.message}"
    Rails.logger.error "[GeminiAgendaProcessor] Raw response: #{raw}"
    []
  end

  # Persists AgendaItem + HousingAppeal records from Gemini's output.
  def persist_appeals(appeals_data)
    return [] if appeals_data.empty?

    Rails.logger.info "[GeminiAgendaProcessor] Persisting #{appeals_data.size} appeal(s) for #{city.name} #{@meeting.meeting_date}"

    appeals_data.filter_map do |data|
      agenda_item = find_or_create_agenda_item(data)
      find_or_create_appeal(agenda_item, data)
    end
  end

  def find_or_create_agenda_item(data)
    AgendaItem.find_or_create_by!(
      council_meeting: @meeting,
      item_number: data["item_number"]
    ) do |item|
      item.title = data["title"].to_s.truncate(255)
      item.description = data["description"]
      item.item_type = "appeal"
      item.project_address = data["project_address"]
      item.apn = data["apn"]
    end
  end

  def find_or_create_appeal(agenda_item, data)
    # Deduplicate by reference_number within the city if available
    if data["reference_number"].present?
      existing = HousingAppeal.find_by(city: city, reference_number: data["reference_number"])
      return existing if existing
    end

    HousingAppeal.create!(
      city: city,
      agenda_item: agenda_item,
      reference_number: data["reference_number"],
      project_name: data["project_name"],
      project_address: data["project_address"] || agenda_item.project_address,
      apn: data["apn"] || agenda_item.apn,
      appellant_name: data["appellant_name"],
      grounds_category: data["grounds_category"],
      grounds_description: data["grounds_description"],
      description: data["appeal_description"],
      status: "filed",
      filed_date: @meeting.meeting_date
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[GeminiAgendaProcessor] Failed to save appeal: #{e.message} — #{data.inspect}"
    nil
  end
end
