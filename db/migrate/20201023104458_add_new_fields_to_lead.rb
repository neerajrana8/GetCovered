class AddNewFieldsToLead < ActiveRecord::Migration[5.2]
  def change
    add_column :leads, :agency_id, :integer

    leads = Lead.pluck(:id)
    leads.each do |lead_id|
      agency_id = LeadEvent.where(lead_id: lead_id).where.not(agency_id: nil).pluck(:agency_id).uniq.last
      Lead.find(lead_id).update(agency_id: agency_id) if agency_id.present?
    end

  end
end

