class AddPageNumberToHousingAppeals < ActiveRecord::Migration[8.1]
  def change
    add_column :housing_appeals, :page_number, :integer
  end
end
