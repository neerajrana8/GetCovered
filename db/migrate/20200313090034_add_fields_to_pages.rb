class AddFieldsToPages < ActiveRecord::Migration[5.2]
  def change
    change_column :branding_profile_attributes, :value, :text
    add_reference :pages, :branding_profile, index: true
  end
end
