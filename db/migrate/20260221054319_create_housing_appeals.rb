class CreateHousingAppeals < ActiveRecord::Migration[8.1]
  def change
    create_table :housing_appeals do |t|
      t.references :city, null: false, foreign_key: true
      t.references :agenda_item, null: true, foreign_key: true
      t.string :reference_number
      t.string :project_name
      t.string :project_address
      t.string :apn
      t.string :appellant_name
      t.string :grounds_category
      t.text :grounds_description
      t.text :summary
      t.string :status, null: false, default: "filed"
      t.date :filed_date
      t.date :decision_date
      t.string :decision

      t.timestamps
    end
    add_index :housing_appeals, [ :city_id, :reference_number ], unique: true
    add_index :housing_appeals, :status
    add_index :housing_appeals, :filed_date
  end
end
