class AddIndicesToAccessTokens < ActiveRecord::Migration[5.2]
  def change
    
    add_index :access_tokens, :key, name: "access_tokens_key_index"
    add_index :access_tokens, :expires_at, name: "access_tokens_expires_at_index"
  end
end
