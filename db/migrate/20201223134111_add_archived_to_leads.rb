class AddArchivedToLeads < ActiveRecord::Migration[5.2]
  def up
    add_column :leads, :archived, :boolean, default: false
  end

  def down
    remove_column :leads, :archived
  end
end
