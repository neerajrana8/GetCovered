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
        renters_warnings = []
        missing_fields = [:username, :password, :database_server, :database_name].map{|s| s.to_s }.select{|field| integration.credentials['voyager'][field].blank? }
        missing_fields.push("url") if integration.credentials['urls']['renters_insurance'].blank?
        renters_issues.push("Your renters insurance configuration is missing fields: #{missing_fields.join(", ")}") unless missing_fields.blank?
        renters_issues.push("You have not enabled renter's insurance integration.") if !integration.configuration['renters_insurance']['enabled']
        if renters_issues.blank?
          result = Integrations::Yardi::RentersInsurance::GetVersionNumber.run!(integration: integration)
          renters_issues.push("We encountered an error while trying to connect to Yardi. Please double-check your configuration and verify that the entity 'Get Covered Insurance' has access to your Renters Insurance interface.") if !result[:success]
        end
        # billing stuff
        billing_issues = []
        billing_warnings = []
        missing_fields = [:username, :password, :database_server, :database_name].map{|s| s.to_s }.select{|field| integration.credentials['billing'][field].blank? }
        missing_fields.push("url") if integration.credentials['urls']['billing_and_payments'].blank?
        billing_issues.push("Your billing & payments configuration is missing fields: #{missing_fields.join(", ")}") unless missing_fields.blank?
        billing_issues.push("You have not enabled billing & payments integration.") if !integration.configuration['billing_and_payments']['enabled']
        if billing_issues.blank?
          result = Integrations::Yardi::BillingAndPayments::GetVersionNumber.run!(integration: integration)
          if !result[:success]
            billing_issues.push("We encountered an error while trying to connect to Yardi. Please double-check your configuration and verify that the entity 'Get Covered Billing' has access to your Billing and Payments interface.")
          else
            result = Integrations::Yardi::BillingAndPayments::GetChargeTypes.run!(integration: integration)
            if !result[:success]
              
              billing_issues.push("Your Yardi account is accessible, but we were unable to retrieve your charge codes / GL account numbers. Please verify that the entity 'Get Covered Billing' has access to your Billing and Payments interface.")
            else
              charge_buckets = result[:parsed_response].dig("Envelope", "Body", "GetChargeTypes_LoginResponse", "GetChargeTypes_LoginResult", "Charges")
              charge_buckets = [charge_buckets] unless charge_buckets.nil? || charge_buckets.class == ::Array
              if charge_buckets.nil?
                billing_issues.push("Your Yardi account is accessible, but we were unable to retrieve your charge codes / GL account numbers. Please verify that the entity 'Get Covered Billing' has access to your Billing and Payments interface.")
              else
                our_bucket = charge_buckets.find{|ct| ct["Entity"] == "Get Covered Billing" }
                if our_bucket.nil?
                  unless !integration.configuration['billing_and_payments']['master_policy_gla'].blank? &&
                         !integration.configuration['billing_and_payments']['master_policy_charge_code'].blank? &&
                         integration.configuration['billing_and_payments']['available_charge_settings'].any? do |ct|
                            ct['charge_code'] == integration.configuration['billing_and_payments']['master_policy_charge_code'] &&
                            ct['gla'] == integration.configuration['billing_and_payments']['master_policy_gla']
                         end
                    billing_issues.push("We were unable to find any charge codes / GL account numbers associated with the entity 'Get Covered Billing' in your Billing and Payments interface; we cannot post master policy charges to your tenants without a charge code & GL account number, so please reattempt connection once such an entry is set up.")
                  end # we skip complaining if we already have valid settings, because it could just be a network issue
                else
                  charge_types = our_bucket["Charge"]
                  charge_types = [charge_types] unless charge_types.nil? || charge_types.class == ::Array
                  case charge_types.length
                    when 0
                      integration.configuration['billing_and_payments']['available_charge_settings'] = []
                      integration.configuration['billing_and_payments']['master_policy_charge_code'] = nil
                      integration.configuration['billing_and_payments']['master_policy_gla'] = nil
                      billing_issues.push("We found a Charge Code entry for the entity 'Get Covered Billing' in your Billing and Payments interface, but were unable to find any charge codes / GL account numbers associated with it; we cannot post master policy charges to your tenants without a charge code & GL account number, so please reattempt connection once such an entry is set up.")
                    when 1
                      integration.configuration['billing_and_payments']['available_charge_settings'] = charge_types.map{|ct| { 'charge_code' => ct['ChargeCode'], 'gla' => ct['GLCode'].first } }
                      integration.configuration['billing_and_payments']['master_policy_charge_code'] = charge_types.first['ChargeCode']
                      integration.configuration['billing_and_payments']['master_policy_gla'] = charge_types.first['GLCode'].first
                    else
                      integration.configuration['billing_and_payments']['available_charge_settings'] = charge_types.map{|ct| { 'charge_code' => ct['ChargeCode'], 'gla' => ct['GLCode'].first } }
                      unless !integration.configuration['billing_and_payments']['master_policy_gla'].blank? &&
                             !integration.configuration['billing_and_payments']['master_policy_charge_code'].blank? &&
                             integration.configuration['billing_and_payments']['available_charge_settings'].any? do |ct|
                                ct['charge_code'] == integration.configuration['billing_and_payments']['master_policy_charge_code'] &&
                                ct['gla'] == integration.configuration['billing_and_payments']['master_policy_gla']
                             end
                        integration.configuration['billing_and_payments']['master_policy_charge_code'] = nil
                        integration.configuration['billing_and_payments']['master_policy_gla'] = nil
                        billing_issues.push("We found more than one Charge Code entry for the entity 'Get Covered Billing' in your Billing and Payments interface; please select which we should use for pushing master policy charges to residents.")
                      end
                  end
                end
              end
            end
            
          end
        end
        # make sure the proper sync-related stuff is set up
        sync_field_issues = prepare_sync_fields(renters_issues, renters_warnings)
        # set issues stuff
        integration.configuration['billing_and_payments']['active'] = billing_issues.blank?
        integration.configuration['billing_and_payments']['configuration_problems'] = billing_issues + billing_warnings
        integration.configuration['renters_insurance']['active'] = renters_issues.blank?
        integration.configuration['renters_insurance']['configuration_problems'] = renters_issues + renters_warnings
        # save changes and return the integration
        integration.save
        return integration
      end
      
      def prepare_sync_fields(renters_issues, renters_warnings = [])
        integration.configuration['sync'] ||= {}
        integration.configuration['sync']['syncable_communities'] ||= {}
        integration.configuration['sync']['pull_policies'] = false if integration.configuration['sync']['pull_policies'].nil?
        integration.configuration['sync']['push_policies'] = false if integration.configuration['sync']['push_policies'].nil?
        integration.configuration['sync']['push_master_policy_invoices'] = false if integration.configuration['sync']['push_master_policy_invoices'].nil?
        integration.configuration['sync']['policy_push'] ||= {}
        integration.configuration['sync']['policy_push']['push_document'] = false if integration.configuration['sync']['policy_push']['push_document'].nil?
        integration.configuration['sync']['policy_push']['attachment_type_options'] ||= []
        integration.configuration['sync']['policy_push']['attachment_type'] ||= nil
        integration.configuration['sync']['master_policy_invoices'] ||= {}
        integration.configuration['sync']['master_policy_invoices']['charge_description'] ||= "Master Policy"
        integration.configuration['sync']['master_policy_invoices']['log'] ||= []
        integration.configuration['sync']['sync_history'] ||= []
        integration.configuration['sync']['next_sync'] ||= nil
        
        # set up syncable_communities
        result = Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!(integration: integration)
        if result[:success] && result[:parsed_response].class == ::Hash
          result[:comms] = result[:parsed_response].dig("Envelope", "Body", "GetPropertyConfigurationsResponse", "GetPropertyConfigurationsResult", "Properties", "Property")
          result[:comms] = [result[:comms]] if result[:comms].class == ::Hash
          if result[:comms].class == ::Array
            integration.configuration['sync']['syncable_communities'] = result[:comms].map{|c| [c["Code"], {
              'name' => c["MarketingName"],
              'gc_id' => (integration.configuration['sync']['syncable_communities'] || {})[c["Code"]]&.[]('gc_id'), # WARNING: insurables sync fills this out
              'enabled' => (integration.configuration['sync']['syncable_communities'] || {})[c["Code"]]&.[]('enabled') ? true : false,
              'insurables_only' => (integration.configuration['sync']['syncable_communities'] || {})[c["Code"]]&.[]('insurables_only') ? true : false,
              'last_sync_i' =>  integration.configuration['sync']['syncable_communities'][c["Code"]]&.[]('last_sync_i'),
              'last_sync_f' => integration.configuration['sync']['syncable_communities'][c["Code"]]&.[]('last_sync_f'),
              'last_sync_p' => integration.configuration['sync']['syncable_communities'][c["Code"]]&.[]('last_sync_p')
            }] }.to_h
          end
        end
        # set up policy push configuration if needed
        result = Integrations::Yardi::ResidentData::GetAttachmentTypes.run!(integration: integration)
        if result[:success] && result[:parsed_response].class == ::Hash && !result[:parsed_response].dig("Envelope", "Body", "GetAttachmentTypesResponse", "GetAttachmentTypesResult", "AttachmentTypes", "Type").nil?
          attachment_types = result[:parsed_response].dig("Envelope", "Body", "GetAttachmentTypesResponse", "GetAttachmentTypesResult", "AttachmentTypes", "Type")
          attachment_types = [attachment_types] unless attachment_types.class == ::Array
          if !attachment_types.blank?
            integration.configuration['sync']['policy_push']['attachment_type_options'] = attachment_types.map{|at| at.class == ::String ? at : at["__content__"] }
            integration.configuration['sync']['policy_push']['attachment_type'] = nil unless integration.configuration['sync']['policy_push']['attachment_type_options'].include?(integration.configuration['sync']['policy_push']['attachment_type'])
          else
            # error no attachment types
            integration.configuration['sync']['policy_push']['attachment_type_options'] = []
            renters_warnings.push("We received an empty list of Attachment Types from your server. Please configure an AttachmentType in Yardi so that we can upload policy documents.")
          end
        else
          # error couldn't make the call
          integration.configuration['sync']['policy_push']['attachment_type_options'] = []
          renters_warnings.push("We were unable to retrieve a list of Attachment Types (labels for uploaded proof-of-policy documents). Please ensure the entity 'Get Covered Insurance' has access to your Yardi ResidentData interface and that an AttachmentType is set up for us to use.")
        end
        # set up next sync if needed
        if integration.configuration['sync']['next_sync'].nil?
          integration.configuration['sync']['next_sync'] = {
            'timestamp' => (Time.current + 1.day).to_date.to_s
          }
          # MOOSE WARNING: add sync job call
        end
        
      end
      
    end
  end
end
