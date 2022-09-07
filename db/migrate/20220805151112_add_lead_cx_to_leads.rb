class AddLeadCxToLeads < ActiveRecord::Migration[6.1]
  def change
    add_column :leads, :lead_events_cx, :integer
    add_column :leads, :lead_events_timeseries, :json
  end
end
