module Integrations
  module Yardi
    class SwapResidentIds < ActiveInteraction::Base
      object :integration
      string :id1
      string :id2
      
      def execute
        ActiveRecord::Base.transaction(requires_new: true) do
          unique_thing = "temporary_swap_time_" + Time.current.to_i + "_" + id1 + "_to_" + id2
          integration.integration_profiles.where(profileable_type: ["User", "LeaseUser"], external_id: id1).update_all(external_id: unique_thing)
          integration.integration_profiles.where(profileable_type: ["User", "LeaseUser"], external_id: id2).update_all(external_id: id1)
          integration.integration_profiles.where(profileable_type: ["User", "LeaseUser"], external_id: unique_thing).update_all(external_id: id2)
        end
      end
      
      
    end
  end
end
