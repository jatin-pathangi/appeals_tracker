require "nokogiri"
require "net/http"
require "uri"
require "openssl"

module Fetchers
  class BaseFetcher
    attr_reader :agenda_source

    def initialize(agenda_source)
      @agenda_source = agenda_source
    end

    # Scrapes all listing pages, downloads agenda PDFs, runs Gemini extraction,
    # and returns an array of CouncilMeeting objects that were created or updated.
    def fetch
      results = []

      each_agenda_listing do |meeting_date, pdf_url|
        meeting = find_or_build_meeting(meeting_date, pdf_url)

        if meeting.new_record? || !meeting.agenda_pdf.attached?
          download_and_attach_pdf(meeting, pdf_url)
          meeting.fetched_at = Time.current
          meeting.save!
          process_with_gemini(meeting)
          results << meeting
        elsif meeting.status == "pending"
          # PDF stored but Gemini previously failed — retry
          process_with_gemini(meeting)
          results << meeting
        else
          Rails.logger.info "[#{self.class.name}] Skipping #{meeting_date} (already processed)"
        end
      end

      agenda_source.update!(last_fetched_at: Time.current)
      results
    end

    private

    # Convenience accessors
    def city   = agenda_source.city
    def config = agenda_source.config

    # Paginates through listing pages using the standard ?page=N convention,
    # yielding [Date, pdf_url] for each agenda found.
    # Stops naturally when a page has no rows within the months_back window.
    def each_agenda_listing
      months_back = config.fetch("months_back", 6).to_i
      oldest_date = Date.today << months_back
      page = 0

      loop do
        url = page.zero? ? "#{base_url}#{listing_path}" : "#{base_url}#{listing_path}?page=#{page}"
        Rails.logger.info "[#{self.class.name}] Scraping listing page #{page}: #{url}"

        doc  = Nokogiri::HTML(fetch_html(url))
        rows = parse_listing_page(doc).select { |date, _| date >= oldest_date }

        break if rows.empty?

        rows.each { |date, pdf_url| yield date, pdf_url }

        page += 1
      end
    end

    def find_or_build_meeting(meeting_date, pdf_url)
      CouncilMeeting.find_or_initialize_by(
        agenda_source: agenda_source,
        meeting_date: meeting_date
      ) do |m|
        m.meeting_type = "regular"
        m.status       = "pending"
        m.pdf_url      = pdf_url
      end
    end

    def download_and_attach_pdf(meeting, url)
      filename = "#{meeting.meeting_date.strftime("%Y%m%d")}_#{city.slug}_agenda.pdf"

      Tempfile.create([ filename, ".pdf" ]) do |tempfile|
        tempfile.binmode

        # Stream the download directly to disk
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          request["User-Agent"] = "AppealTracker/1.0"

          http.request(request) do |response|
            response.read_body do |chunk|
              tempfile.write(chunk)
            end
          end
        end

        tempfile.rewind

        meeting.agenda_pdf.attach(
          io: tempfile,
          filename: filename,
          content_type: "application/pdf"
        )
      end
    end

    def process_with_gemini(meeting)
      GeminiAgendaProcessor.new(meeting).process
      meeting.update!(status: "processed")
      Rails.logger.info "[#{self.class.name}] Gemini processing complete for #{meeting.meeting_date}"
    rescue StandardError => e
      Rails.logger.error "[#{self.class.name}] Gemini processing failed for #{meeting.meeting_date}: #{e.message}"
      # Status stays "pending" so this meeting is retried on the next fetch run
    end

    def fetch_html(url)
      http_get(url).body
    end

    # GET with redirect following and SSL verification disabled.
    def http_get(url, limit = 10)
      raise "Too many redirects fetching #{url}" if limit.zero?

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.get(uri.request_uri, "User-Agent" => "AppealTracker/1.0")
      end

      case response
      when Net::HTTPSuccess    then response
      when Net::HTTPRedirection then http_get(response["Location"], limit - 1)
      else raise "HTTP #{response.code} fetching #{url}"
      end
    end

    # -------------------------------------------------------------------------
    # Template methods — subclasses MUST implement these
    # -------------------------------------------------------------------------

    # Base URL of the city's council website (e.g. "https://sfbos.org")
    def base_url
      raise NotImplementedError, "#{self.class} must implement #base_url"
    end

    # Path to the meetings listing page (e.g. "/meetings/full-board-meetings")
    def listing_path
      raise NotImplementedError, "#{self.class} must implement #listing_path"
    end

    # Parses a Nokogiri document for a single listing page.
    # Must return an array of [Date, pdf_url_string] pairs.
    # Return an empty array when the page has no agenda rows (signals end of pagination).
    def parse_listing_page(doc)
      raise NotImplementedError, "#{self.class} must implement #parse_listing_page(doc)"
    end
  end
end
