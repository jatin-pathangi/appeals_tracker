class CreateCouncilMeetings < ActiveRecord::Migration[8.1]
  def change
    create_table :council_meetings do |t|
      t.references :agenda_source, null: false, foreign_key: true
      t.date :meeting_date, null: false
      t.string :meeting_type, null: false, default: "regular"
      t.string :pdf_url
      t.string :status, null: false, default: "pending"
      t.datetime :fetched_at

      t.timestamps
    end
    add_index :council_meetings, [ :agenda_source_id, :meeting_date ], unique: true
    add_index :council_meetings, :status
  end
end
