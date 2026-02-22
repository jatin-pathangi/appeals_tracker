class AddDescriptionToHousingAppeals < ActiveRecord::Migration[8.1]
  def change
    add_column :housing_appeals, :description, :text
  end
end
