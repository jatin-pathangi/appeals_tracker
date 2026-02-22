class AgendaSource < ApplicationRecord
  belongs_to :city
  has_many :council_meetings, dependent: :destroy
  has_many :agenda_items, through: :council_meetings

  validates :fetcher_class, presence: true
  validates :agenda_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid HTTP(S) URL" }

  scope :active, -> { where(active: true) }

  # Instantiate and return the fetcher class for this source.
  # The class must exist under lib/fetchers/ and inherit from Fetchers::BaseFetcher.
  def fetcher
    fetcher_class.constantize.new(self)
  end
end
