module Integrations
  module Yardi
    module Sync
      class Policies < ActiveInteraction::Base
        object :integration
        string :property_id
        date :from_date, default: nil
        
        
        def execute
          # set up the appropriate config fields if not yet set up (all changes to the integration save at the end, so if something breaks hideously we will entirely repeat the process)
          integration.configuration ||= {}
          integration.configuration['last_policy_sync'] ||= {}
          start_date = from_date&.to_s || integration.configuration['last_policy_sync'][property_id]
          integration.configuration['last_policy_sync'][property_id] = Time.current.to_date # MOOSE WARNING: minus 1 to ensure overlap? or is it good?
          integration.configuration['pending_yardi_policy_numbers'] ||= {}
          # get data on policies updated since our last run
          the_response = nil
          result = Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: property_id, **{ policy_date_last_modified: start_date }.compact)
          if !result[:success]
            return { status: :error, message: "Yardi server error (request failed)", event: result[:event] }
          end
          policy_hashes = result[:parsed_response].dig("Envelope", "Body", "GetInsurancePoliciesResponse", "GetInsurancePoliciesResult", "RenterInsurance", "InsurancePolicy") || []
          # get data on policies that for whatever reason we need to try importing regardless of updated status (maybe we failed to save a Policy record for them last time, for example)
          not_present_in_yardi = [] # track policy numbers that were in pending_yardi_policy_numbers but that Yardi says it's never heard of
          new_pending_yardi_numbers = []
          (integration.configuration['pending_yardi_policy_numbers'][property_id] || []).each do |pn|
            result = Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: property_id, policy_number: pn)
            if result[:success]
              obj = result[:parsed_response].dig("Envelope", "Body", "GetInsurancePoliciesResponse", "GetInsurancePoliciesResult", "RenterInsurance", "InsurancePolicy")
              if obj.nil?
                not_present_in_yardi.push(pn)
              else
                policy_hashes.push(obj)
              end
            else
              new_pending_yardi_numbers.push(pn) # we got an actual FAILED REQUEST, so leave it in for next time
            end
          end
          if new_pending_yardi_numbers.blank?
            integration.configuration['pending_yardi_policy_numbers'].delete(property_id)
          else
            integration.configuration['pending_yardi_policy_numbers'][property_id] = new_pending_yardi_numbers
          end
          # attempt to create or update policies 
          in_system = ::IntegrationProfile.references(:policies).includes(:policy).where(external_context: 'policy', external_id: policy_hashes.map{|ph| ph["PolicyNumber"] })
          in_system_ids = in_system.map{|ip| ip.profileable_id }
          in_system = in_system.group_by{|ip| ip.policy.number }.transform_values!{|vs| vs.first }
          import_results = policy_hashes.map do |polhash|
            ########## MOOSE WARNING do it
          end
          
          
          
          # get data on internal policies that haven't yet been exported
          unexported = Policy.where.not(id: in_system_ids)#...
        
        end
        
        
      end
    end
  end
end
