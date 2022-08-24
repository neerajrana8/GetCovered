class UpdateMissingAccountAndAgencyForPolicies < ActiveRecord::Migration[6.1]
  def change
    policies_to_update_account = Policy.where(status: "EXTERNAL_UNVERIFIED",account_id: nil)
    policies_to_update_agency = Policy.where(status: "EXTERNAL_UNVERIFIED",agency_id: nil)

    policies_to_update_account.each do |policy|
      account_id = policy.insurables&.last&.account&.id
      policy.update(account_id: account_id) if account_id.present?
    end

    policies_to_update_agency.each do |policy|
      agency_id = policy.insurables&.last&.account&.agency&.id
      policy.update(agency_id: agency_id) if agency_id.present?
    end
  end
end
