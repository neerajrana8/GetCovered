module Integrations
  module Yardi
    module Sync
      class Policies < ActiveInteraction::Base
        object :integration
        string :property_list_id, default: nil
        array :property_ids, default: nil
        date :from_date, default: nil
        
        
        def execute
          ##############################################################
          ###################### MANAGE ARGUMENTS ######################
          ##############################################################

          to_return = {
            policy_import_errors: {},
            policy_export_errors: {},
            policy_update_errors: {},
            policies_imported: {},
            policies_updated: {},
            policies_exported: {}
          }
          
          true_property_ids = property_ids.nil? ? integration.configuration['sync']['syncable_communities'].map{|k,v| v['enabled'] && v['gc_id'] ? k : nil }.compact : property_ids
        
          if true_property_ids.nil?
            # get em all
            propz = Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!({ integration: integration, property_id: property_list_id }.compact)
            propz = propz&.[](:parsed_response)&.dig("Envelope", "Body", "GetPropertyConfigurationsResponse", "GetPropertyConfigurationsResult", "Properties", "Property")
            propz = [propz] if !propz.nil? && propz.class != ::Array
            propz = propz&.map{|comm| comm["Code"] }
            return(to_return) if propz.blank?
            return propz.inject(to_return){|tr, property_id| tr.deep_merge(Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id])) }
          elsif true_property_ids.length > 1
            return true_property_ids.inject(to_return){|tr, property_id| tr.deep_merge(Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id])) }
          elsif true_property_ids.length == 0
            return(to_return)
          end
          property_id = true_property_ids.first
          the_community = IntegrationProfile.where(integration: integration, external_context: "community", external_id: property_id).take.profileable
          ##############################################################
          ###################### SETUP #################################
          ##############################################################
        
          # set up the appropriate config fields if not yet set up (all changes to the integration save at the end, so if something breaks hideously we will entirely repeat the process)
          error_count = 0
          integration.configuration ||= {}
          integration.configuration['last_policy_sync'] ||= {}
          start_date = from_date&.to_s || integration.configuration['last_policy_sync'][property_id]
          integration.configuration['last_policy_sync'][property_id] = Time.current.to_date # MOOSE WARNING: minus 1 to ensure overlap? or is it good?
          integration.configuration['pending_yardi_policy_numbers'] ||= {}
          # get data on policies updated since our last run
          the_response = nil
          result = Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: property_id, **{ policy_date_last_modified: start_date }.compact)
          if !result[:success]
            to_return[:policy_import_errors]["all"] = "Yardi server error: request failed (Event id #{result[:event].id})"
            to_return[:policy_export_errors]["all"] = "Yardi server error: request failed (Event id #{result[:event].id})"
            to_return[:policy_update_errors]["all"] = "Yardi server error: request failed (Event id #{result[:event].id})"
            return to_return
          end
          the_event = result[:event]
          policy_hashes = result[:parsed_response].dig("Envelope", "Body", "GetInsurancePoliciesResponse", "GetInsurancePoliciesResult", "RenterInsurance", "InsurancePolicy") || []
          policy_hashes = [policy_hashes] unless policy_hashes.class == ::Array
          in_system_user_list = ::IntegrationProfile.where(
            integration: integration,
            profileable_type: "User",
            external_context: "resident",
            external_id: policy_hashes.map do |ph|
              temp = ph.dig("Customer", "Identification")
              next nil if temp.nil?
              temp = [temp] unless temp.class == ::Array
              temp.map{|t| t["IDValue"] }
            end.compact.flatten,
            profileable_type: "User"
          ).select(:external_id, :profileable_id).distinct.pluck(:external_id, :profileable_id).to_h
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
                if obj.class == ::Array
                  policy_hashes.concat(obj)
                else
                  policy_hashes.push(obj)
                end
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
                
          ##############################################################
          ###################### IMPORT FROM YARDI #####################
          ##############################################################
          
          # construct a hash in_system[policy_number] = { policy: policy_object, integration_profile: ip_object_or_nil }
          in_system = ::Policy.where(number: policy_hashes.map{|ph| ph["PolicyNumber"] })
          in_system_ips = ::IntegrationProfile.where(external_context: 'policy', profileable: in_system)
          in_system = in_system.group_by{|p| p.number }.transform_values{|vs| { policy: vs.first } }
          in_system_ips.each{|ip| dat_hash = in_system[ip.external_id]; next if dat_hash.nil?; dat_hash[:integration_profile] = ip }
          in_system_ips = nil # so ruby can garbage collect
          in_system_ids = in_system.map{|num,is| is[:policy].id } # for later use
          # group up in-system and out-of-system policies
          import_results = policy_hashes.group_by{|polhash| in_system[polhash["PolicyNumber"]] ? true : false }
          import_results[true] ||= []
          import_results[false] ||= []
          # policy create and update
          if integration.configuration['sync']['pull_policies']
            
            # policies update section
            import_results[true].each do |polhash|
              data = in_system[polhash["PolicyNumber"]]
              ############# MOOSE WARNING: no policy update implemented except for IP creation ###########
              if data[:integration_profile].nil?
                created_ip = IntegrationProfile.create(
                  integration: integration,
                  profileable: data[:policy],
                  external_context: "policy",
                  external_id: data[:policy].number,
                  configuration: {
                    'history' => 'matched_with_yardi_record',
                    'synced_at' => Time.current.to_s
                  }
                )
                if created_ip.id.nil?
                  integration.configuration['pending_yardi_policy_numbers'] ||= []
                  integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
                  integration.configuration['pending_yardi_policy_numbers'][property_id].push(data[:policy].number)
                  to_return[:policy_import_errors][data[:policy].number] = "In-system policy #{data[:policy].number} matches Yardi record, but failed to create IntegrationProfile (#{created_ip.errors.to_h}). Policy added to pending import list."
                end
              end
            end
            to_return[:policy_update_errors]['all'] = "Yardi sync policy updates are currently disabled." unless import_results[true].blank?
            # policies creation section
            lease_ips = ::IntegrationProfile.references(:leases).includes(:lease)
                            .order(external_id: :asc)
                            .where(
                              integration: integration,
                              external_context: "lease",
                              external_id: import_results[false]&.map{|polhash| polhash.dig("Customer", "Lease", "Identification", "IDValue") },
                              profileable_type: "Lease"
                            )
            created_lease_ips = []
            import_results[false]&.each do |polhash|
              next if ((Date.parse(polhash["PolicyDetails"]["EffectiveDate"]).year < 2002) rescue true) # flee from messed up MP listings
              next if ((Date.parse(polhash["PolicyDetails"]["ExpirationDate"]).year < 2002) rescue true) # flee from messed up MP listings
              lease = lease_ips.find{|ip| ip.external_id == polhash.dig("Customer", "Lease", "Identification", "IDValue") }&.lease ||
                      created_lease_ips.find{|ip| ip.external_id == polhash.dig("Customer", "Lease", "Identification", "IDValue") }&.lease
              if lease.nil?
                integration.configuration['pending_yardi_policy_numbers'] ||= []
                integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
                integration.configuration['pending_yardi_policy_numbers'][property_id].push(polhash["PolicyNumber"])
                to_return[:policy_import_errors][polhash["PolicyNumber"]] = "Lease (Yardi ID (#{polhash.dig("Customer", "Lease", "Identification", "IDValue")}) not found in system. Policy added to pending import list."
                next
              end
              # policy requires creation
              # first, parse user info
              user_hashes = polhash.dig("Customer", "Identification").class == ::Array ? polhash.dig("Customer", "Identification") : [polhash.dig("Customer", "Identification")]
              user_hashes.each{|uh| uh["gc_id"] = in_system_user_list[uh["IDValue"]] }
              if user_hashes.any?{|uh| uh["gc_id"].nil? }
                integration.configuration['pending_yardi_policy_numbers'] ||= []
                integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
                integration.configuration['pending_yardi_policy_numbers'][property_id].push(polhash["PolicyNumber"])
                to_return[:policy_import_errors][polhash["PolicyNumber"]] = "Tenant (Yardi ID #{user_hashes.select{|uh| uh["gc_id"].nil? }.map{|uh| uh["IDValue"] }.join(", ")}) not found in system. Policy added to pending import list."
                next
              end
              princeps = user_hashes.find{|uh| uh["IDType"] == "Resident ID" } || user_hashes.first # just in caes for some reason there is no Resident ID one, better to record something than nothing
              # then, create policy
              begin
                created = nil
                created_ip = nil
                ActiveRecord::Base.transaction do
                  created = Policy.create!(
                    number: polhash["PolicyNumber"],
                    effective_date: Date.parse(polhash["PolicyDetails"]["EffectiveDate"]),
                    expiration_date: Date.parse(polhash["PolicyDetails"]["ExpirationDate"]),
                    auto_renew: false,
                    status: "EXTERNAL_VERIFIED",
                    billing_enabled: false,
                    system_purchased: false, # we need?
                    serviceable: false, # wut iz dis?
                    account: integration.integratable,
                    agency: nil,
                    carrier: nil,
                    policy_type_id: PolicyType::RESIDENTIAL_ID,
                    policy_in_system: false,
                    auto_pay: false,
                    address: [polhash["Customer"]["Address"]["Address"], polhash["Customer"]["Address"]["City"], polhash["Customer"]["Address"]["State"], polhash["Customer"]["Address"]["PostalCode"]].join(", "),
                    out_of_system_carrier_title: polhash.dig("Insurer", "Name")
                  )
                  PolicyInsurable.create!(primary: true, policy_application_id: nil, policy_id: created.id, insurable_id: lease.insurable_id)
                  pu = PolicyUser.create!(primary: true, spouse: false, policy_application_id: nil, policy_id: created.id, user_id: princeps["gc_id"])
                  IntegrationProfile.create!(
                    integration: integration,
                    profileable: pu,
                    external_context: "policy_user_for_policy_#{policy.number}",
                    external_id: princeps["IDValue"]
                  )
                  user_hashes.each do |uh|
                    next if uh == princeps
                    pu = PolicyUser.create!(primary: false, spouse: false, policy_application_id: nil, policy_id: created.id, user_id: uh["gc_id"])
                    IntegrationProfile.create!(
                      integration: integration,
                      profileable: pu,
                      external_context: "policy_user_for_policy_#{policy.number}",
                      external_id: uh["IDValue"]
                    )
                  end
                  if polhash["PolicyDetails"]["LiabilityAmount"]
                    created.policy_coverages.create!(
                      policy_application: nil,
                      title: "Liability",
                      designation: "LiabilityAmount",
                      limit: (polhash["PolicyDetails"]["LiabilityAmount"].to_d * 100).floor,
                      deductible: nil,
                      enabled: true
                    )
                  end
                  if polhash["PolicyDetails"]["IsPetEndorsement"] == "true"
                    created.policy_coverages.create!(
                      policy_application: nil,
                      title: "Pet Endorsement",
                      designation: "IsPetEndorsement",
                      limit: nil,
                      deductible: nil,
                      enabled: true
                    )
                  end
                  created_ip = IntegrationProfile.create!(
                    integration: integration,
                    profileable: created,
                    external_context: "policy",
                    external_id: created.number,
                    configuration: {
                      'history' => 'imported_from_yardi',
                      'synced_at' => Time.current.to_s
                    }
                  )
                  in_system_ids.push(created.id)
                  in_system[created.number] = { policy: created, integration_profile: created_ip }
                end
                to_return[:policies_imported][polhash["PolicyNumber"]] = created
                created_lease_ips.push(created_ip)
              rescue ActiveRecord::RecordInvalid => err
                temp = err.record.errors.to_h
                unless err.record.class == ::Policy && temp.length == 1 && temp[:number] == "has already been taken"
                  # we only log this policy as pending (to force ourselves to look at it again next import attempt) if the problem WASN'T that it already exists in our database
                  integration.configuration['pending_yardi_policy_numbers'] ||= []
                  integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
                  integration.configuration['pending_yardi_policy_numbers'][property_id].push(polhash["PolicyNumber"])
                end
                to_return[:policy_import_errors][polhash["PolicyNumber"]] = "Failed to create #{err.record.class.name}: #{err.record.errors.to_h}. Yardi policy hash was: #{polhash}"
              end
              next
            end # end policy creation block

          end # end policy create/update block
          
          ##############################################################
          ###################### EXPORT TO YARDI #######################
          ##############################################################
          if integration.configuration['sync']['push_policies']
            # get data on internal policies that haven't yet been exported
            unexported_policy_ids = Policy.where(
              id: PolicyInsurable.where(insurable: the_community.insurables).where.not(policy_id: nil).pluck(:policy_id),
              policy_type_id: [::PolicyType::RESIDENTIAL_ID], #, ::PolicyType::MASTER_COVERAGE_ID],
              status: ::Policy.active_statuses,
            ).where.not(id: IntegrationProfile.where(integration: integration, profileable_type: "Policy").pluck(:profileable_id)).pluck(:id)
            unexported_policy_ids.each do |pol_id|
              # verify that the policy really should be exported and prepare a users list
              policy = Policy.where(id: pol_id).references(:policy_insurables, :policy_users).includes(:policy_insurables, :policy_users).take
              lease_users = LeaseUser.includes(:lease).references(:leases).where(user_id: policy.policy_users.map{|pu| pu.user_id }, leases: { insurable_id: policy.policy_insurables.find{|pi| pi.primary }&.insurable_id })
              next nil if lease_users.blank?
              lease_user_ips = IntegrationProfile.includes(lease_user: :user).references(:lease_users, :users).where(integration: integration, profileable: lease_users)
              next nil if lease_user_ips.blank?
              users_to_export = policy.policy_users.to_a.map do |pu|
                found = lease_user_ips.find{|lup| lup.lease_user.user_id == pu.user_id }
                next nil if found.nil?
                unless pu.integration_profiles.where(integration: integration).count > 0
                  IntegrationProfile.create(
                    integration: integration,
                    profileable: pu,
                    external_context: "policy_user_for_policy_#{policy.number}",
                    external_id: found.external_id
                  )
                end
                next {
                  policy_user: pu,
                  external_id: found.external_id
                }
              end.compact
              roommate_index = 0
              next if users_to_export.blank?
              # export the policy
              priu = users_to_export.find{|u| u[:policy_user].primary }
              policy_hash = {
                Customer: {
                  Identification: users_to_export.map{|u| { "IDValue" => u[:external_id], "IDType" => u[:policy_user].primary ? "Resident ID" : "Roomate#{roommate_index += 1} ID" } },
                  Name: {
                      "FirstName" => priu[:policy_user].user.profile.first_name,
                      "MiddleName" => priu[:policy_user].user.profile.middle_name.blank? ? nil : priu[:policy_user].user.profile.middle_name,
                      "LastName" => priu[:policy_user].user.profile.last_name#,
                      #"Relationship"=> priu[:policy_user].primary ? nil : priu[:policy_user].spouse ? "Spouse" : "Roommate"
                  }.compact
                },
                Insurer: { Name: policy.carrier&.title || policy.out_of_system_carrier_title },
                PolicyNumber: policy.number,
                PolicyTitle: policy.number,
                PolicyDetails: {
                  EffectiveDate: policy.effective_date.to_s,
                  ExpirationDate: policy.expiration_date&.to_s, # MOOSE WARNING: should we do something else for MPCs?
                  IsRenew: policy.auto_renew,
                  LiabilityAmount: '%.2f' % (policy.get_liability.nil? ? nil : (policy.get_liability.to_d / 100.to_d)) #,
                  #Notes: "GC Verified" #, TEMP DISALBRD CAUSSES BROKEENNN
                  #IsRequiredForMoveIn: "false",
                  #IsPMInterestedParty: "true"
                  # MOOSE WARNING: are these weirdos required?
                }.compact
              }
              result = Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: property_id, policy_hash: policy_hash, change: false)
              if result[:success]
                created_ip = IntegrationProfile.create(
                  integration: integration,
                  profileable: policy,
                  external_context: "policy",
                  external_id: policy.number,
                  configuration: {
                    'history' => 'exported_to_yardi',
                    'synced_at' => Time.current.to_s
                  }
                )
                if(created_ip.id.nil?)
                  to_return[:policy_export_errors][policy.number] = "Failed to create IntegrationProfile: #{created_ip.errors.to_h}"
                  next
                end
                to_return[:policies_exported][policy.number] = policy
              else
                to_return[:policy_export_errors][policy.number] = "Failed to export policy due to error response from Yardi's API (Event id #{result[:event]&.id})."
              end
            end.compact # end export process; we ignore some instead of reporting errors, because they might not be exportable policies and we only found out when we looked at them in detail

          end # end if pull_policies
          
          ##############################################################
          ###################### CLOSING UP SHOP #######################
          ##############################################################
          integration.configuration['sync']['sync_history'] ||= []
          integration.configuration['sync']['sync_history'].push({
            'log_format' => '1.0',
            'event_type' => "sync_policies",
            'message' => "Synced policies for Yardi property '#{property_id}'.",
            'timestamp' => Time.current.to_s,
            'errors' => to_return.select{|k,v| k.to_s.end_with?("errors") }
          })
          integration.save
          return to_return
          
        end # end method
        
        
      end
    end
  end
end
