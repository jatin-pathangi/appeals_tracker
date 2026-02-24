module Fetchers
  class BerkeleyFetcher < BaseFetcher
    private

    def base_url     = "https://berkeleyca.gov"
    def listing_path = "/your-government/city-council/city-council-agendas"

    # Berkeley's agenda page is a single table (no pagination).
    # Each <tr> contains:
    #   td.council-meeting-name  → link text "City Council YYYY-MM-DD - Regular/Special/..."
    #   td.council-meeting-minutes → one or more PDF links
    #
    # We only process Regular meetings and take the first agenda-packet PDF
    # (skipping annotated agendas, which are second links on the same row).
    def parse_listing_page(doc)
      doc.css("tr").filter_map do |row|
        title_link = row.at_css("td.council-meeting-name a")
        next unless title_link

        title = title_link.text.strip
        # Only pick up Regular meetings; skip Special, Closed Session, etc.
        next unless title =~ /City Council (\d{4}-\d{2}-\d{2}) - Regular/i

        meeting_date = Date.parse($1)

        pdf_link = row.at_css("td.council-meeting-minutes a[href$='.pdf']")
        next unless pdf_link

        pdf_url = "#{base_url}#{pdf_link["href"]}"

        [ meeting_date, pdf_url ]
      end
    end
  end
end
