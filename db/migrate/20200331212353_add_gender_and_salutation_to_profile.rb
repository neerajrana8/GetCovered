class AddGenderAndSalutationToProfile < ActiveRecord::Migration[5.2]
  def change
    add_column :profiles, :gender, :integer, :default => 0
    add_column :profiles, :salutation, :integer, :default => 0
  end
end
