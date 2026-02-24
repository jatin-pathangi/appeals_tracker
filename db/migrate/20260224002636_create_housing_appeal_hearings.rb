class CreateHousingAppealHearings < ActiveRecord::Migration[8.1]
  def change
    create_table :housing_appeal_hearings do |t|
      t.references :housing_appeal, null: false, foreign_key: true, index: true
      t.references :council_meeting, null: false, foreign_key: true, index: true

      # What kind of hearing this was at this specific meeting
      t.string :hearing_type, null: false, default: "other"

      # What actually happened at this meeting (e.g. "Continued to Feb 24, 2026")
      t.text :action_taken

      # Per-hearing Gemini summaries (may differ from one meeting to the next)
      t.text :description
      t.text :grounds_description
      t.integer :page_number

      t.timestamps
    end

    # An appeal can only appear once per meeting
    add_index :housing_appeal_hearings,
              [ :housing_appeal_id, :council_meeting_id ],
              unique: true,
              name: "idx_hearings_appeal_meeting"
  end
end
