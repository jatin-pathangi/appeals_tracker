class CouncilMeeting < ApplicationRecord
  belongs_to :agenda_source
  has_many :agenda_items, dependent: :destroy
  has_many :housing_appeals, through: :agenda_items
  has_one :city, through: :agenda_source

  has_one_attached :agenda_pdf

  MEETING_TYPES = %w[regular special closed_session].freeze
  STATUSES = %w[pending processed error].freeze

  validates :meeting_date, presence: true
  validates :meeting_type, inclusion: { in: MEETING_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :agenda_source, uniqueness: { scope: :meeting_date, message: "already has a meeting on this date" }

  scope :pending, -> { where(status: "pending") }
  scope :processed, -> { where(status: "processed") }
  scope :recent, -> { order(meeting_date: :desc) }
  scope :for_city, ->(city) { joins(:agenda_source).where(agenda_sources: { city: city }) }
end
