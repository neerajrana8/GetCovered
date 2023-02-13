class AddSynonymsAndIsSystemToCarriers < ActiveRecord::Migration[6.1]
  def change
    add_column :carriers, :synonyms, :string
    add_column :carriers, :is_system, :boolean, default: false, null: false
  end
end
