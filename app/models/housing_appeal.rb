class HousingAppeal < ApplicationRecord
  belongs_to :city
  belongs_to :agenda_item, optional: true
  has_many :housing_appeal_hearings, dependent: :destroy
  has_many :council_meetings, through: :housing_appeal_hearings

  STATUSES = %w[filed pending heard decided withdrawn].freeze
  DECISIONS = %w[granted denied continued withdrawn].freeze
  GROUNDS_CATEGORIES = %w[CEQA design_review use_permit neighborhood_impact procedural other].freeze

  validates :city, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :decision, inclusion: { in: DECISIONS }, allow_nil: true
  validates :grounds_category, inclusion: { in: GROUNDS_CATEGORIES }, allow_nil: true
  validates :reference_number, uniqueness: { scope: :city_id, message: "already exists for this city" }, allow_nil: true

  scope :by_status, ->(s) { where(status: s) }
  scope :open, -> { where.not(status: %w[decided withdrawn]) }
  scope :decided, -> { where(status: "decided") }
  scope :granted, -> { where(decision: "granted") }
  scope :denied, -> { where(decision: "denied") }
  scope :recent, -> { order(filed_date: :desc) }
  scope :for_city, ->(city) { where(city: city) }
  scope :by_apn, ->(apn) { where(apn: apn) }

  def self.valid_status(raw)
    parsed = raw.to_s.downcase.strip
    STATUSES.include?(parsed) ? parsed : "filed"
  end

  def self.valid_decision(raw)
    parsed = raw.to_s.downcase.strip
    DECISIONS.include?(parsed) ? parsed : nil
  end
end
