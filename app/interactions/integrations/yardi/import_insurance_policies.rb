module Integrations
  module Yardi
    class ImportInsurancePolicies < Integrations::Yardi::BaseVoyagerRentersInsurance
      string :property_id #getcov00
      policy :string # some xml
      def execute
        throw "NOT ALLOWED RIGHT NOW BRO"
        super(**{
          YardiPropertyId: property_id,
          Policy: policy
        }.compact)
      end
    end
  end
end
