class City < ApplicationRecord
  has_many :agenda_sources, dependent: :destroy
  has_many :council_meetings, through: :agenda_sources
  has_many :housing_appeals, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :state_code, presence: true

  before_validation :set_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { joins(:agenda_sources).where(agenda_sources: { active: true }).distinct }

  def to_param
    slug
  end

  private

  def set_slug
    self.slug = name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
  end
end
