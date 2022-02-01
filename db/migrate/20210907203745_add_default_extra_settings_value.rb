class AddDefaultExtraSettingsValue < ActiveRecord::Migration[5.2]
  def change
    change_column_default :policy_applications, :extra_settings, {}
  end
end
