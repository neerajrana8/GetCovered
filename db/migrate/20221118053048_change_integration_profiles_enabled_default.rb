class ChangeIntegrationProfilesEnabledDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default :integration_profiles, :enabled, from: false, to: true
  end
end
