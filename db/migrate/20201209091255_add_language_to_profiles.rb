class AddLanguageToProfiles < ActiveRecord::Migration[5.2]
  def change
    add_column :profiles, :language, :integer, default: 0
  end
end
