class AddAdditionalInterestName < ActiveRecord::Migration[6.1]
  def change
    add_column :insurables, :additional_interest_name, :string
  end
end
