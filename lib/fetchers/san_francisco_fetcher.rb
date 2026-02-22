require "nokogiri"
require "net/http"
require "uri"
require "date"
require "openssl"

module Fetchers
  class SanFranciscoFetcher < BaseFetcher
    BASE_URL = "https://sfbos.org"
    LISTING_PATH = "/meetings/full-board-meetings"

    # Scrapes all pages of the SF BOS full board meetings listing,
    # finds agenda PDFs, downloads them, and stores them via ActiveStorage
    # on CouncilMeeting records.
    #
    # Returns an array of CouncilMeeting objects that were created or updated.
    def fetch
      results = []

      each_agenda_listing do |meeting_date, pdf_url|
        meeting = find_or_build_meeting(meeting_date, pdf_url)

        if meeting.new_record? || !meeting.agenda_pdf.attached?
          download_and_attach_pdf(meeting, pdf_url)
          meeting.fetched_at = Time.current
          meeting.save! # Save with status still "pending" until Gemini confirms

          process_with_gemini(meeting)
          results << meeting
        elsif meeting.status == "pending"
          # PDF already stored but Gemini processing previously failed — retry
          process_with_gemini(meeting)
          results << meeting
        else
          Rails.logger.info "[SanFranciscoFetcher] Skipping #{meeting_date} (already processed)"
        end
      end

      agenda_source.update!(last_fetched_at: Time.current)
      results
    end

    private

    # Yields [Date, String] pairs for every agenda found across all listing pages.
    def each_agenda_listing
      page = 0

      loop do
        url = page.zero? ? "#{BASE_URL}#{LISTING_PATH}" : "#{BASE_URL}#{LISTING_PATH}?page=#{page}"
        Rails.logger.info "[SanFranciscoFetcher] Scraping listing page #{page}: #{url}"

        html = fetch_html(url)
        doc = Nokogiri::HTML(html)
        rows = doc.css("table.views-table tr")

        break if rows.empty?

        found_any = false

        rows.each do |row|
          date_node = row.at_css("td.views-field-field-date .date-display-single")
          agenda_node = row.at_css("td.views-field-field-meeting-type-1 a")
          next unless date_node && agenda_node

          found_any = true
          meeting_date = Date.parse(date_node["content"])
          pdf_url = "#{BASE_URL}#{agenda_node["href"]}"

          yield meeting_date, pdf_url
        end

        # Stop if no agenda rows found on this page (e.g. past end of pagination)
        break unless found_any

        # Stop early if the config specifies a max_pages limit
        max_pages = config.fetch("max_pages", nil)
        break if max_pages && page >= max_pages.to_i - 1

        page += 1
      end
    end

    def process_with_gemini(meeting)
      GeminiAgendaProcessor.new(meeting).process
      meeting.update!(status: "processed")
      Rails.logger.info "[SanFranciscoFetcher] Gemini processing complete for #{meeting.meeting_date}"
    rescue StandardError => e
      Rails.logger.error "[SanFranciscoFetcher] Gemini processing failed for #{meeting.meeting_date}: #{e.message}"
      # Status stays "pending" so this meeting is retried on the next fetch run
    end

    def find_or_build_meeting(meeting_date, pdf_url)
      CouncilMeeting.find_or_initialize_by(
        agenda_source: agenda_source,
        meeting_date: meeting_date
      ) do |m|
        m.meeting_type = "regular"
        m.status = "pending"
        m.pdf_url = pdf_url
      end
    end

    # Downloads the PDF at the given URL and attaches it to the meeting's
    # agenda_pdf ActiveStorage attachment.
    def download_and_attach_pdf(meeting, url)
      response = http_get(url)
      filename = "#{meeting.meeting_date.strftime("%Y%m%d")}_sf_bos_agenda.pdf"
      meeting.agenda_pdf.attach(
        io: StringIO.new(response.body),
        filename: filename,
        content_type: "application/pdf"
      )
    end

    # Fetches raw HTML from a URL.
    def fetch_html(url)
      http_get(url).body
    end

    # Makes a GET request following redirects, with SSL verification disabled.
    def http_get(url, limit = 10)
      raise "Too many redirects fetching #{url}" if limit.zero?

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.get(uri.request_uri, "User-Agent" => "AppealTracker/1.0")
      end

      case response
      when Net::HTTPSuccess then response
      when Net::HTTPRedirection then http_get(response["Location"], limit - 1)
      else raise "HTTP #{response.code} fetching #{url}"
      end
    end
  end
end
