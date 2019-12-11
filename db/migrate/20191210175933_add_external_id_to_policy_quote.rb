class AddExternalIdToPolicyQuote < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_quotes, :external_id, :string
    add_index :policy_quotes, :external_id, unique: true
  end
end
