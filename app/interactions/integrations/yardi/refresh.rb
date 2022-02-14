module Integrations
  module Yardi
    class Refresh< ActiveInteraction::Base
      object :integration
      
    
      def execute
        if integration.provider != 'yardi'
          return nil
        end
        # ensure the basic schema is present
        integration.credentials ||= {}
        integration.credentials['voyager'] ||= {}
        integration.credentials['billing'] ||= {}
        integration.credentials['urls'] ||= {}
        integration.configuration ||= {}
        integration.configuration['renters_insurance'] ||= {}
        integration.configuration['billing_and_payments'] ||= {}
        # renters stuff
        renters_issues = []
        missing_fields = [:username, :password, :database_server, :database_name].map{|s| s.to_s }.select{|field| integration.credentials['voyager'][field].blank? }
        missing_fields.push("url") if integration.credentials['urls']['renters_insurance'].blank?
        renters_issues.push("Your renters insurance configuration is missing fields: #{missing_fields.join(", ")}") unless missing_fields.blank?
        renters_issues.push("You have not enabled renter's insurance integration.") if !integration.configuration['renters_insurance']['enabled']
        if renters_issues.blank?
          result = Integrations::Yardi::RentersInsurance::GetVersionNumber.run!(integration: integration)
          renters_issues.push("We encountered an error while trying to connect to Yardi. Please double-check your configuration.") if !result[:success]
        end
        integration.configuration['renters_insurance']['active'] = renters_issues.blank?
        integration.configuration['renters_insurance']['configuration_problems'] = renters_issues
        # billing stuff
        billing_issues = []
        missing_fields = [:username, :password, :database_server, :database_name].map{|s| s.to_s }.select{|field| integration.credentials['billing'][field].blank? }
        missing_fields.push("url") if integration.credentials['urls']['billing_and_payments'].blank?
        billing_issues.push("Your billing & payments configuration is missing fields: #{missing_fields.join(", ")}") unless missing_fields.blank?
        renters_issues.push("You have not enabled billing & payments integration.") if !integration.configuration['billing_and_payments']['enabled']
        if billing_issues.blank?
          result = Integrations::Yardi::BillingAndPayments::GetVersionNumber.run!(integration: integration)
          renters_issues.push("We encountered an error while trying to connect to Yardi. Please double-check your configuration.") if !result[:success]
        end
        integration.configuration['billing_and_payments']['active'] = billing_issues.blank?
        integration.configuration['billing_and_payments']['configuration_problems'] = billing_issues
        # make sure the proper sync-related stuff is set up
        prepare_sync_fields
        # save changes and return the integration
        integration.save
        return integration
      end
      
      def prepare_sync_fields
        integration.configuration['sync'] ||= {}
        integration.configuration['sync']['syncable_communities'] ||= {}
        integration.configuration['sync']['sync_history'] ||= []
        integration.configuration['sync']['next_sync'] ||= nil
        
        # set up syncable_communities
        result = Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!(integration: integration)
        if result[:success] && result[:parsed_response].class == ::Hash
          result[:comms] = result[:parsed_response].dig("Envelope", "Body", "GetPropertyConfigurationsResponse", "GetPropertyConfigurationsResult", "Properties", "Property")
          if result[:comms].class == ::Array
            integration.configuration['sync']['syncable_communities'] = result[:comms].map{|c| [c["Code"], {
              'name' => c["MarketingName"],
              'gc_id' => (integration.configuration['sync']['syncable_communities'] || {})[c["Code"]]&.[]('gc_id'), # WARNING: insurables sync fills this out
              'enabled' => (integration.configuration['sync']['syncable_communities'] || {})[c["Code"]]&.[]('enabled') ? true : false
            }] }.to_h
          end
        end
        # set up next sync if needed
        if integration.configuration['sync']['next_sync'].nil?
          integration.configuration['sync']['next_sync'] = {
            timestamp: (Time.current + 1.day).beginning_of_day
          }
          # MOOSE WARNING: add sync job call
        end
        
      end
      
    end
  end
end
