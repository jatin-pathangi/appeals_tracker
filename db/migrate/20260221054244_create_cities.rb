class CreateCities < ActiveRecord::Migration[8.1]
  def change
    create_table :cities do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :state_code, null: false, default: "CA"
      t.string :county

      t.timestamps
    end
    add_index :cities, :slug, unique: true
    add_index :cities, :name
  end
end
