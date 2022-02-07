class AddIsCarrierFeeToPolicyCoverage < ActiveRecord::Migration[6.1]
  def change
    add_column :policy_coverages, :is_carrier_fee, :boolean, default: false
  end
end
