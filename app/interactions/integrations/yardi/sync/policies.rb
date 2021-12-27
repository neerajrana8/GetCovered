module Integrations
  module Yardi
    module Sync
      class Policies < ActiveInteraction::Base
        object :integration
        string :property_id
        date :from_date, default: nil
        
        
        def execute
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
            return { status: :error, message: "Yardi server error (request failed)", event: result[:event] }
          end
          the_event = result[:event]
          policy_hashes = result[:parsed_response].dig("Envelope", "Body", "GetInsurancePoliciesResponse", "GetInsurancePoliciesResult", "RenterInsurance", "InsurancePolicy") || []
          in_system_user_list = ::IntegrationProfile.where(
            integration: integration,
            external_context: "resident"
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
          
          
          ##############################################################
          ###################### IMPORT FROM YARDI #####################
          ##############################################################
          
          
          # do some preliminary stuff
          in_system = ::IntegrationProfile.references(:policies).includes(:policy).where(external_context: 'policy', external_id: policy_hashes.map{|ph| ph["PolicyNumber"] })
          in_system_ids = in_system.map{|ip| ip.profileable_id }
          in_system = in_system.group_by{|ip| ip.policy.number }.transform_values!{|vs| vs.first }
          import_results = policy_hashes.group_by{|polhash| in_system[polhash["PolicyNumber"]] ? true : false }
          # policies update section
          import_results[true].map! do |polhash|
            # these guys are already in the system... y r dey heer?
            next { status: :success, operation: :update, policy_number: polhash["PolicyNumber"], note: "Didn't actually perform any update actions. Update actions are presently disabled." }
          end
          # policies creation section
          lease_ips = ::IntegrationProfile.references(:leases).includes(:leases)
                          .order(external_id: :asc)
                          .where(
                            integration: integration,
                            external_id: import_results[false].map{|polhash| polhash.dig("Customer", "Lease", "Identification", "IDValue") }
                            profileable_type: "Lease"
                          ).select(:external_id, :'lease.id', :'lease.insurable_id')
          import_results[false].map! do |polhash|
            lease = lease_ips.find{|ip| ip.external_id == polhash.dig("Customer", "Lease", "Identification", "IDValue") }&.lease
            if lease.nil?
              integration.configuration['pending_yardi_policy_numbers'] ||= []
              integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
              integration.configuration['pending_yardi_policy_numbers'][property_id].push(polhash["PolicyNumber"])
              error_count += 1
              next { status: :error, operation: :create, policy_number: polhash["PolicyNumber"], message: "Lease ID (#{polhash.dig("Customer", "Lease", "Identification", "IDValue")}) not found in system. Policy added to pending import list." }
            end
            # policy requires creation
            # first, parse user info            
            user_hashes = polhash.dig("Customer", "Identification").class == ::Array ? polhash.dig("Customer", "Identification") : [polhash.dig("Customer", "Identification")]
            user_hashes.each{|uh| uh["gc_id"] = in_system_user_list[uh["IDValue"]] }
            if user_hashes.any?{|uh| uh["gc_id"].nil? }
              integration.configuration['pending_yardi_policy_numbers'] ||= []
              integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
              integration.configuration['pending_yardi_policy_numbers'][property_id].push(polhash["PolicyNumber"])
              error_count += 1
              next { status: :error, operation: :create, policy_number: polhash["PolicyNumber"], message: "Tenant ID (#{user_hashes.select{|uh| uh["gc_id"].nil? }.map{|uh| uh["IDValue"] }.join(", ")}) not found in system. Policy added to pending import list." }
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
                PolicyUser.create!(primary: true, spouse: false, policy_application_id: nil, policy_id: created.id, user_id: princeps["gc_id"])
                user_hashes.each{|uh| next if uh == princeps; PolicyUser.create!(primary: false, spouse: false, policy_application_id: nil, policy_id: created.id, user_id: uh["gc_id"]) }
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
                in_system[created.number] = created_ip
              end
              next { status: :success, operation: :create, policy_number: created.number, policy: created, integration_profile: created_ip }
            rescue ActiveRecord::RecordInvalid => err
              integration.configuration['pending_yardi_policy_numbers'] ||= []
              integration.configuration['pending_yardi_policy_numbers'][property_id] ||= []
              integration.configuration['pending_yardi_policy_numbers'][property_id].push(polhash["PolicyNumber"])
              error_count += 1
              next { status: :error, operation: :create, policy_number: polhash["PolicyNumber"], message: "Failed to create #{err.record.class.name}: #{err.record.errors.to_h}" }
            end
          end # end policy creation block
          # merge up the import results
          import_results = import_results.values
          
          
          ##############################################################
          ###################### EXPORT TO YARDI #######################
          ##############################################################
          
          
          # get data on internal policies that haven't yet been exported
          unexported_policy_ids = PolicyUser.where.not(policy_id: nil).where.not(policy_id: in_system_ids).where(user_id: in_system_user_list.values).pluck(:policy_id).uniq
          export_results = unexported_policy_ids.map do |pol_id|
            # verify that the policy really should be exported and prepare a users list
            policy = Policy.where(id: pol_id).references(:policy_insurables, :policy_users).includes(:policy_insurables, :policy_users).take
            lease_users = LeaseUser.where(user_id: policy.policy_users.map{|pu| pu.user_id }, insurable_id: policy.policy_insurables.find{|pi| pi.primary }&.insurable_id)
            next nil if lease_users.blank?
            lease_user_ips = IntegrationProfile.where(integration: integration, profileable_type: "User", profileable_id: lease_users.map{|lu| lu.user_id })
            next nil if lease_user_ips.blank?
            users_to_export = policy.policy_users.to_a.map do |pu|
              found = lease_user_ips.find{|lup| lup.profileable_id == pu.user_id }
              next nil if found.nil?
              next {
                policy_user: pu,
                external_id: found.external_id
              }
            end.compact
            roommate_index = 0
            # export the policy
            policy_hash = {
              Customer: {
                Identification: users_to_export.map{|u| { "IDValue" => u[:external_id], "IDType" => u[:policy_user].primary ? "Resident ID" : "Roomate#{roommate_index += 1} ID" } }
                Name: users_to_export.mapdo |u|
                  {
                    "FirstName" => u[:policy_user].user.profile.first_name,
                    "MiddleName" => u[:policy_user].user.profile.middle_name.blank? ? nil : u[:policy_user].user.profile.middle_name,
                    "LastName" => u[:policy_user].user.profile.last_name,
                    "Relationship"=> u[:policy_user].primary ? nil : u[:policy_user].spouse ? "Spouse" : "Roommate"
                  }.compact
                end
              },
              Insurer: { Name: policy.carrier&.title || policy.out_of_system_carrier_title },
              PolicyNumber: policy.number,
              PolicyTitle: policy.number,
              PolicyDetails: {
                EffectiveDate: policy.effective_date.to_s,
                ExpirationDate: policy.expiration_date.to_s,
                IsRenew: policy.auto_renew,
                LiabilityAmount: policy.get_liability #,
                #IsRequiredForMoveIn: "false",
                #IsPMInterestedParty: "true"
                # MOOSE WARNING: are these weirdos required?
              }
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
                error_count += 1
                next { status: :error, operation: :export, policy_number: policy.number, policy: policy, event: event, message: "Successfully exported policy but failed to create IntegrationProfile: #{created_ip.errors.to_h}" }
              end
              next { status: :success, operation: :export, policy_number: policy.number, policy: policy, integration_profile: created_ip, event: event }
            end
            error_count += 1
            next { status: :error, operation: :export, policy_number: policy.number, message: "Failed to export policy due to error response from Yardi's API: #{result[:parsed_response]}", event: result[:event] }
          end.compact # end export process; we ignore some instead of reporting errors, because they might not be exportable policies and we only found out when we looked at them in detail
          
          
          ##############################################################
          ###################### CLOSING UP SHOP #######################
          ##############################################################
          integration.save
          return { status: :success, results: import_results + export_results, error_count: error_count, event: the_event }
          
            
        
        end # end method
        
        
      end
    end
  end
end
