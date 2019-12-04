class AddMailchimpIdAndMailchimpCategoryToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :mailchimp_id, :string
    add_index :users, :mailchimp_id, unique: true
    add_column :users, :mailchimp_category, :integer, :default => 0
  end
end
