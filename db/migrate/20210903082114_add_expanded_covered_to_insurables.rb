class AddExpandedCoveredToInsurables < ActiveRecord::Migration[5.2]
  def change
    add_column :insurables, :expanded_covered, :jsonb, null: false, default: {}
  end
end
