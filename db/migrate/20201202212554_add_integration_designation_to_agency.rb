class AddIntegrationDesignationToAgency < ActiveRecord::Migration[5.2]
  def change
    add_column :agencies, :integration_designation, :string
    add_index :agencies, :integration_designation, unique: true
  end
end
