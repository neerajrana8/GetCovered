class AddEnabledToPolicyCoverages < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_coverages, :enabled, :boolean, null: false, default: false
  end
end
