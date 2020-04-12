class CreateCommissionDeductions < ActiveRecord::Migration[5.2]
  def change
    create_table :commission_deductions do |t|
      t.integer :unearned_balance
      t.references :deductee, polymorphic: true, index: true
      t.references :policy, index: true
      
      t.timestamps
    end
    add_column :policy_premia, :unearned_premium, :integer, :default => 0
  end
end
