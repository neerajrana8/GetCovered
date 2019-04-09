class CreateProfiles < ActiveRecord::Migration[5.2]
  def change
    create_table :profiles do |t|
      t.string :first_name
      t.string :last_name
      t.string :middle_name
      t.string :title
      t.string :suffix
      t.string :full_name
      t.string :contact_email
      t.string :contact_phone
      t.date :birth_date
      t.references :profileable, polymorphic: true

      t.timestamps
    end
  end
end
