class AddAdditionalInterestToAccount < ActiveRecord::Migration[6.1]
  def change
    add_column :accounts, :additional_interest, :boolean, default: true
  end
end
