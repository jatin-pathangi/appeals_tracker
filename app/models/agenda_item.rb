class AgendaItem < ApplicationRecord
  belongs_to :council_meeting
  has_many :housing_appeals, dependent: :nullify
  has_one :agenda_source, through: :council_meeting
  has_one :city, through: :council_meeting

  ITEM_TYPES = %w[appeal variance permit other].freeze

  validates :title, presence: true
  validates :item_type, inclusion: { in: ITEM_TYPES }, allow_nil: true

  scope :appeals, -> { where(item_type: "appeal") }
  scope :for_meeting, ->(meeting) { where(council_meeting: meeting) }
  scope :ordered, -> { order(:item_number) }
end
