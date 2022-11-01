class AddAffordableToInsurables < ActiveRecord::Migration[6.1]
  def change
    add_column :insurables, :special_status, :integer, null: false, default: 0
    # 'normal', 'affordable'
  end
end
