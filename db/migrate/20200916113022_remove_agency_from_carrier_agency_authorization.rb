class RemoveAgencyFromCarrierAgencyAuthorization < ActiveRecord::Migration[5.2]
  def change
    remove_column :carrier_agency_authorizations, :agency_id
  end
end
