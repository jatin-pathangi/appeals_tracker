class CreateAgendaSources < ActiveRecord::Migration[8.1]
  def change
    create_table :agenda_sources do |t|
      t.references :city, null: false, foreign_key: true
      t.string :fetcher_class, null: false
      t.string :agenda_url, null: false
      t.jsonb :config, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.datetime :last_fetched_at

      t.timestamps
    end
    add_index :agenda_sources, :active
  end
end
