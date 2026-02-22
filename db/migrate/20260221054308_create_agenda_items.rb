class CreateAgendaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :agenda_items do |t|
      t.references :council_meeting, null: false, foreign_key: true
      t.integer :item_number
      t.string :title
      t.text :description
      t.string :item_type
      t.string :project_address
      t.string :apn

      t.timestamps
    end
  end
end
