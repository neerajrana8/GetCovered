class AddFieldsToAccessToken < ActiveRecord::Migration[5.2]
  def change
    add_column :access_tokens, :access_type, :integer, null: false, default: 0
    add_column :access_tokens, :access_data, :jsonb
    add_column :access_tokens, :expires_at, :datetime
  end
end
