class HousingAppealHearing < ApplicationRecord
  belongs_to :housing_appeal
  belongs_to :council_meeting

  HEARING_TYPES = %w[filing initial continued action public_comment decision communication other].freeze

  # Hearings with substantive new content shown in full;
  # non-substantive ones render as compact timeline chips.
  SUBSTANTIVE_TYPES = %w[initial decision action].freeze

  validates :hearing_type, inclusion: { in: HEARING_TYPES }

  scope :chronological,     -> { joins(:council_meeting).order("council_meetings.meeting_date ASC") }
  scope :reverse_chron,     -> { joins(:council_meeting).order("council_meetings.meeting_date DESC") }
  scope :substantive,       -> { where(hearing_type: SUBSTANTIVE_TYPES) }
  scope :non_substantive,   -> { where.not(hearing_type: SUBSTANTIVE_TYPES) }

  def substantive?
    hearing_type.in?(SUBSTANTIVE_TYPES)
  end

  def hearing_date
    council_meeting.meeting_date
  end

  def pdf_url_with_page
    base = council_meeting.pdf_url
    return nil if base.blank?
    page_number ? "#{base}#page=#{page_number}" : base
  end
end
