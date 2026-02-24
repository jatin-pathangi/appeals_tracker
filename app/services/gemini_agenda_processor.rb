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

  PROMPT_TEMPLATE = <<~PROMPT
    You are analyzing a city council meeting agenda PDF.

    Your task: extract every housing project appeal on this agenda.

    For each appeal found, return a JSON object in the following array format.
    If no appeals are found, return an empty array [].

    Return ONLY valid JSON — no markdown, no explanation, just the array.

    Schema for each appeal object:
    {
      "item_number": <integer or null>,
      "page_number": <integer — the PDF page number where this appeal item appears, or null if unknown>,
      "hearing_type": "<one of: filing (initial receipt of the appeal), initial (the first substantive hearing on the matter), continued (the case was deferred or continued to a future date), action (board took an intermediate action), public_comment (public comment period only), decision (the board makes a final determination), communication (letters, briefs, or documents received without a substantive hearing), other. Choose the most specific option rather than 'other'.>",
      "action_taken": "<what happened at THIS specific hearing, e.g. 'Continued to March 11, 2026', 'Board voted 4-1 to uphold the appeal', 'Public comment period only', or null if not clear>",
      "appeal_status": "<what is the overall status of this appeal AFTER this hearing? MUST BE one of: filed, pending, heard, decided, withdrawn. Crucially: if the appeal is being heard today or was heard in the past, it is NO LONGER 'filed', it is at least 'pending' or 'heard'.>",
      "appeal_decision": "<what was the ultimate decision on this appeal? one of: granted, denied, continued, withdrawn. Use null if no decision has been made yet.>",
      "title": "<short agenda item title>",
      "description": "<full text of the agenda item>",
      "appeal_description": "<2-4 sentence plain-English summary: what is being appealed, who is appealing, and the main grounds. Write this for a general audience with no technical jargon>",
      "project_name": "<name of the housing project, or null>",
      "project_address": "<street address, or null>",
      "apn": "<Assessor Parcel Number, or null>",
      "appellant_name": "<name of appellant(s), or null>",
      "grounds_category": "<one of: CEQA, design_review, use_permit, neighborhood_impact, procedural, other>",
      "grounds_description": "<summary of the grounds for appeal>",
      "reference_number": "<the Board of Appeals file number ONLY (e.g. '260021'). Do NOT include planning department case numbers like '2024-011561CUA' — if multiple numbers appear, return only the appeal/file number>"
    }

    ---
    EXISTING APPEALS CONTEXT:
    The following is a JSON list of currently active appeals in this city.
    If you find an appeal on this agenda that matches one of these existing appeals:
    1. You MUST USE the exact same `reference_number` provided in the JSON below.
    2. For `action_taken`, read their previous context below and summarize ONLY what is NEW or what specific action is being taken at this meeting (e.g., "Hearing continued for further public comment", "Final board decision issued"). Do not re-summarize the entire original case history.
    3. Update `appeal_status` and `appeal_decision` appropriately. If the new action was a final decision, update the status to `decided` and pick the correct decision.

    Active Appeals JSON:
    %{active_appeals}
    ---
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

    prompt = PROMPT_TEMPLATE % { active_appeals: build_active_appeals_json }

    response = @client.models.generate_content(
      model: MODEL,
      contents: [ pdf_file, prompt ]
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

  # Finds or creates the canonical HousingAppeal, then always records a
  # HousingAppealHearing for this specific meeting.
  def find_or_create_appeal(agenda_item, data)
    ref = normalize_reference_number(data["reference_number"])

    appeal = if ref.present?
               HousingAppeal.find_or_create_by!(city: city, reference_number: ref) do |a|
                 a.agenda_item = agenda_item
                 a.project_name = data["project_name"]
                 a.project_address = data["project_address"] || agenda_item.project_address
                 a.apn = data["apn"] || agenda_item.apn
                 a.appellant_name = data["appellant_name"]
                 a.grounds_category = data["grounds_category"]
                 a.grounds_description = data["grounds_description"]
                 a.description = data["appeal_description"]
                 a.page_number = data["page_number"]
                 a.status = HousingAppeal.valid_status(data["appeal_status"])
                 a.decision = HousingAppeal.valid_decision(data["appeal_decision"])
                 a.filed_date = @meeting.meeting_date
               end
    else
               HousingAppeal.create!(
                 city: city,
                 agenda_item: agenda_item,
                 project_name: data["project_name"],
                 project_address: data["project_address"] || agenda_item.project_address,
                 apn: data["apn"] || agenda_item.apn,
                 appellant_name: data["appellant_name"],
                 grounds_category: data["grounds_category"],
                 grounds_description: data["grounds_description"],
                 description: data["appeal_description"],
                 page_number: data["page_number"],
                 status: HousingAppeal.valid_status(data["appeal_status"]),
                 decision: HousingAppeal.valid_decision(data["appeal_decision"]),
                 filed_date: @meeting.meeting_date
               )
    end

    # If the appeal already existed, update its status and decision based on this newer hearing
    if appeal && !appeal.new_record? && @meeting.meeting_date >= appeal.filed_date
      status = HousingAppeal.valid_status(data["appeal_status"])
      decision = HousingAppeal.valid_decision(data["appeal_decision"])

      # Only override if Gemini thinks the status actually progressed or explicitly gave a decision
      appeal.update(status: status) if status != "filed"
      appeal.update(decision: decision) if decision.present?
    end

    create_hearing(appeal, agenda_item, data) if appeal
    appeal
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[GeminiAgendaProcessor] Failed to save appeal: #{e.message} — #{data.inspect}"
    nil
  end

  def build_active_appeals_json
    # Find all "open" appeals for this city (not decided/withdrawn)
    appeals = HousingAppeal.where(city: city).open.includes(:housing_appeal_hearings)

    if appeals.empty?
      return "[] (No active appeals)"
    end

    appeals.map do |a|
      last_hearing = a.housing_appeal_hearings.order(created_at: :desc).first
      {
        reference_number: a.reference_number,
        project_address: a.project_address,
        previous_summary: a.description,
        last_hearing_date: last_hearing&.hearing_date,
        last_action_taken: last_hearing&.action_taken
      }
    end.to_json
  end

  def create_hearing(appeal, agenda_item, data)
    hearing_type = data["hearing_type"].presence
    hearing_type = "other" unless HousingAppealHearing::HEARING_TYPES.include?(hearing_type)

    HousingAppealHearing.find_or_create_by!(
      housing_appeal: appeal,
      council_meeting: agenda_item.council_meeting
    ) do |h|
      h.hearing_type       = hearing_type
      h.action_taken       = data["action_taken"]
      h.description        = data["appeal_description"]
      h.grounds_description = data["grounds_description"]
      h.page_number        = data["page_number"]
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[GeminiAgendaProcessor] Failed to save hearing: #{e.message}"
  end

  # Normalizes a reference number to the bare appeal file number.
  # Strips planning-dept case numbers and other trailing tokens that Gemini
  # sometimes appends (e.g. '260021; 2024-011561CUA' → '260021').
  def normalize_reference_number(raw)
    return nil if raw.blank?
    raw.to_s.split(/[;,\s]+/).first.strip.presence
  end
end
