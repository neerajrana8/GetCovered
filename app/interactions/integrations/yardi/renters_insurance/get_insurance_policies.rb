module Integrations
  module Yardi
    module RentersInsurance
      class GetInsurancePolicies < Integrations::Yardi::RentersInsurance::Base
        string :property_id #getcov00
        string :tenant_id, default: nil
        string :policy_number, default: nil
        date_time :policy_date_last_modified, default: nil
        def execute
          super(**{
            YardiPropertyId: property_id,
            TenantId: tenant_id,
            PolicyNumber: policy_number,
            PolicyDateLastModified: policy_date_last_modified&.to_date&.to_s
          }.compact)
        end
      end
    end
  end
end
