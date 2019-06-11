class CreateAddresses < ActiveRecord::Migration[5.2]
  def change
    create_table :addresses do |t|
      t.string :street_number
      t.string :street_name
      t.string :street_two
      t.string :city
      t.string :state
      t.string :county
      t.string :zip_code
      t.string :plus_four
      t.string :country
      t.string :full
      t.string :full_searchable
      t.float :latitude
      t.float :longitude
      t.string :timezone
      t.references :addressable, polymorphic: true

      t.timestamps
    end
  end
end
