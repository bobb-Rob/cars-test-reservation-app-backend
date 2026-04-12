class AddPriceAndCategoryToCars < ActiveRecord::Migration[7.0]
  def change
    add_column :cars, :price_per_day, :decimal, precision: 10, scale: 2
    add_column :cars, :category, :string
  end
end
