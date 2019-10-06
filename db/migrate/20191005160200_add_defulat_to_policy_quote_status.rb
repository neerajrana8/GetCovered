class AddDefulatToPolicyQuoteStatus < ActiveRecord::Migration[5.2]
  def change
    change_column :policy_quotes, :status, :integer, :default => 0
  end
end
