class CreateAccessTokens < ActiveRecord::Migration[5.2]
  def change
    create_table :access_tokens do |t|
      t.string :key
      t.string :secret
      t.string :secret_hash
      t.string :secret_salt
      t.boolean :enabled
      t.references :bearer, polymorphic: true

      t.timestamps
    end
  end
end
