class AddAdditionalInterestNameToAccount < ActiveRecord::Migration[6.1]
  def change
    add_column :accounts, :additional_interest_name, :string
  end
end
