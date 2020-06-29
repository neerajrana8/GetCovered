class CreateFaqs < ActiveRecord::Migration[5.2]
  def change
    create_table :faqs do |t|
      t.string :title
      t.integer :branding_profile_id

      t.timestamps
    end
    add_index :faqs, :branding_profile_id
  end
end
