module Fetchers
  class SanFranciscoFetcher < BaseFetcher
    private

    def base_url     = "https://sfbos.org"
    def listing_path = "/meetings/full-board-meetings"

    # Parses one page of the SF BOS meetings table.
    # Returns [[Date, pdf_url], ...] for each row that has an agenda link.
    def parse_listing_page(doc)
      doc.css("table.views-table tr").filter_map do |row|
        date_node   = row.at_css("td.views-field-field-date .date-display-single")
        agenda_node = row.at_css("td.views-field-field-meeting-type-1 a")
        next unless date_node && agenda_node

        meeting_date = Date.parse(date_node["content"])
        pdf_url      = "#{base_url}#{agenda_node["href"]}"

        [ meeting_date, pdf_url ]
      end
    end
  end
end
