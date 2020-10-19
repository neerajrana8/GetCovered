class AddExtraSettingsToPolicyApplications < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :extra_settings, :jsonb
  end
end
