class AddFieldsToAccessToken < ActiveRecord::Migration[5.2]
  def change
    add_column :access_tokens, :access_type, :integer
    add_column :access_tokens, :access_data, :jsonb
  end
end
