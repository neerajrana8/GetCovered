class AddSynonymsAndIsSystemToCarriers < ActiveRecord::Migration[6.1]
  def change
    # NOTE: synonyms field contains comma-separated title synonyms e.g. 'MSI,MSI2,MSI3'
    add_column :carriers, :synonyms, :string
    add_column :carriers, :is_system, :boolean, default: false, null: false
  end
end
