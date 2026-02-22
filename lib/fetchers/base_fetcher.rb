module Fetchers
  class BaseFetcher
    attr_reader :agenda_source

    def initialize(agenda_source)
      @agenda_source = agenda_source
    end

    # Returns an array of hashes, each representing a discovered council meeting:
    #   [{ meeting_date: Date, pdf_url: String, meeting_type: String }, ...]
    #
    # Subclasses MUST implement this method.
    def fetch
      raise NotImplementedError, "#{self.class} must implement #fetch"
    end

    private

    # Convenience accessor for the city this source belongs to.
    def city
      agenda_source.city
    end

    # Access fetcher-specific config stored on the AgendaSource.
    def config
      agenda_source.config
    end
  end
end
