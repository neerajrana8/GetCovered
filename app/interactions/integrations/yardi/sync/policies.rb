module Integrations
  module Yardi
    module Sync
      class Policies < ActiveInteraction::Base
        object :integration
        string :property_list_id, default: nil
        array :property_ids, default: nil
        date :from_date, default: nil
        boolean :efficiency_mode, default: false    
        boolean :fake_export, default: false               # if true, does everything normally but aborts before actually pushing policies
        boolean :universal_export, default: false          # if true, forcibly attempts to sync even policies that do not appear to have changed or to have anything unsunc
        boolean :early_presence_check, default: true       # if true, checks for policy presence before even deciding whether it should be exported in the first place
        array :exportable_ids, default: nil               # if non-nil, restricts the export to only the supplied policies (won't export them if they wouldn't have exported anyway, though)
        
        def export_policy_document(property_id:, policy:, resident_id:, policy_ip: policy.integration_profiles.to_a.find{|pip| pip.integration_id == integration.id }.take)
          return "Document push not enabled" unless integration.configuration.dig('sync', 'policy_push', 'push_document')
          return "Attachment type not set up" unless !integration.configuration.dig('sync', 'policy_push', 'attachment_type').blank?
          return false unless policy.documents.count > 0 # return false instead of nil to say not only were there no errors but also we didn't do anything
          return false unless !policy_ip.configuration['exported_to_primary']
          
          problem = nil
          policy_document = policy.documents.last # MOOSE WARNING: change to something more reliable once we have a system for labelling documents properly
          attachment_result = nil
          result2 = nil
          policy_ip.configuration['content_type'] = policy_document.content_type
          case policy_document.content_type
            when 'application/pdf'
              result2 = Integrations::Yardi::ResidentData::ImportTenantLeaseDocumentPDF.run!(
                integration: integration,
                property_id: property_id,
                resident_id: resident_id,
                attachment_type: integration.configuration['sync']['policy_push']['attachment_type'],
                description: "(GC) Policy ##{policy.number}",
                attachment: policy_document,
                eventable: policy
              )
              attachment_result = (result2[:parsed_response].dig("Envelope", "Body", "ImportTenantLeaseDocumentPDFResponse", "ImportTenantLeaseDocumentPDFResult", "ImportAttach", "DocumentAttachment", "Result") rescue nil)
              attachment_result ||= (result2[:parsed_response].dig("Envelope", "soap:Body", "ImportTenantLeaseDocumentPDFResponse", "ImportTenantLeaseDocumentPDFResult", "ImportAttach", "DocumentAttachment", "Result") rescue nil)
            else
              result2 = Integrations::Yardi::ResidentData::ImportTenantLeaseDocumentExt.run!(
                integration: integration,
                property_id: property_id,
                resident_id: resident_id,
                attachment_type: integration.configuration['sync']['policy_push']['attachment_type'],
                description: "(GC) Policy ##{policy.number}",
                attachment: policy_document,
                eventable: policy,
                file_extension: policy_document.content_type.split("/").last
              )
              attachment_result = (result2[:parsed_response].dig("Envelope", "Body", "ImportTenantLeaseDocumentExtResponse", "ImportTenantLeaseDocumentExtResult", "ImportAttach", "DocumentAttachment", "Result") rescue nil)
              attachment_result ||= (result2[:parsed_response].dig("Envelope", "soap:Body", "ImportTenantLeaseDocumentExtResponse", "ImportTenantLeaseDocumentExtResult", "ImportAttach", "DocumentAttachment", "Result") rescue nil)
          end
          policy_ip.configuration['exported_documents_to'] ||= {}
          if !attachment_result.blank? && attachment_result.start_with?("Successful")
            #policy_ip.configuration['exported_to_primary_as'] = (attachment_result.split(':')[1] rescue nil) # cut off initial "Successful:"
            #policy_ip.configuration['exported_to_primary_freak_response'] = result2[:parsed_response] if  policy_ip.configuration['exported_to_primary_as'].nil?
            policy_ip.configuration['exported_to_primary'] = true # disabled just in case it was causing duplicate uploads: if policy.policy_users.find{|pu| pu.primary }&.integration_profiles&.take&.external_id == resident_id
            policy_ip.configuration['exported_documents_to'][resident_id] = { success: true, event_id: result2[:event]&.id, filename: (attachment_result.split(':')[1] rescue nil) }
            unless policy_ip.save
              problem = "Had a problem saving policy IP changes: #{policy_ip.errors.to_h}"
            end
            IntegrationProfile.create(
              integration: integration,
              profileable: policy_ip,
              external_context: "policy_document_push_log",
              external_id: Time.current.to_s,
              configuration: {
                success: true,
                property_id: property_id,
                resident_id: resident_id,
                attachment_type: integration.configuration['sync']['policy_push']['attachment_type'],
                description: "(GC) Policy ##{policy.number}",
                file_extension: policy_document.content_type.split("/").last,
                filename: (attachment_result.split(':')[1] rescue nil),
                event: result2[:event]&.id,
                attachment_result: attachment_result,
                problem: problem
              }
            )
          else
            problem = "Yardi responded to our upload request in a way that could not be understood."
            policy_ip.configuration['exported_to_primary'] = false
            #policy_ip.configuration['exported_to_primary_as'] = nil
            #policy_ip.configuration['exported_to_primary_freak_response'] = result2[:parsed_response]
            policy_ip.configuration['exported_documents_to'][resident_id] = { success: false, event_id: result2[:event]&.id }
            policy_ip.save
            IntegrationProfile.create(
              integration: integration,
              profileable: policy_ip,
              external_context: "policy_document_push_log",
              external_id: Time.current.to_s,
              configuration: {
                success: false,
                property_id: property_id,
                resident_id: resident_id,
                attachment_type: integration.configuration['sync']['policy_push']['attachment_type'],
                description: "(GC) Policy ##{policy.number}",
                file_extension: policy_document.content_type.split("/").last,
                filename: nil,
                event: result2[:event]&.id,
                attachment_result: attachment_result,
                problem: problem
              }
            )
          end
          return problem
        end
        
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
            policies_exported: {},
            policy_documents_exported: []
          }
          
          true_property_ids = property_ids.nil? ? integration.configuration['sync']['syncable_communities'].map{|k,v| v['enabled'] && v['gc_id'] && !v['insurables_only'] ? k : nil }.compact : property_ids
        
          if true_property_ids.nil?
            # get em all
            propz = Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!({ integration: integration, property_id: property_list_id }.compact)
            propz = propz&.[](:parsed_response)&.dig("Envelope", "Body", "GetPropertyConfigurationsResponse", "GetPropertyConfigurationsResult", "Properties", "Property")
            propz = [propz] if !propz.nil? && propz.class != ::Array
            propz = propz&.map{|comm| comm["Code"] }
            return(to_return) if propz.blank?
            if efficency_mode
              propz.each{|propid| Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [propid], efficiency_mode: true, fake_export: fake_export, universal_export: universal_export, early_presence_check: early_presence_check, exportable_ids: exportable_ids) }
              return to_return # blank
            end
            return propz.inject(to_return){|tr, property_id| tr.deep_merge(Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id], efficiency_mode: false, fake_export: fake_export, universal_export: universal_export, early_presence_check: early_presence_check, exportable_ids: exportable_ids)) }
          elsif true_property_ids.length > 1
            if efficiency_mode
              true_property_ids.each{|propid| Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id], efficiency_mode: true, fake_export: fake_export, universal_export: universal_export, early_presence_check: early_presence_check, exportable_ids: exportable_ids) }
              return to_return # blank
            end
            return true_property_ids.inject(to_return){|tr, property_id| tr.deep_merge(Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id], efficiency_mode: false, fake_export: fake_export, universal_export: universal_export, early_presence_check: early_presence_check, exportable_ids: exportable_ids)) }
          elsif true_property_ids.length == 0
            return(to_return)
          end
          property_id = true_property_ids.first
          the_community_ip = IntegrationProfile.where(integration: integration, external_context: "community", external_id: property_id).take
          the_community = the_community_ip.profileable
          
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
          if integration.configuration['sync']['pull_policies']
          
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
              end.compact.flatten
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

          end # end if pull_policies
          
          ##############################################################
          ###################### EXPORT TO YARDI #######################
          ##############################################################
          if integration.configuration['sync']['push_policies']
            # get data on internal policies that haven't yet been exported
            policy_ids = (
              Policy.where(
                id: PolicyInsurable.where(insurable: the_community.units).where.not(policy_id: nil).select(:policy_id),
                policy_type_id: [::PolicyType::RESIDENTIAL_ID], #, ::PolicyType::MASTER_COVERAGE_ID],
                status: ::Policy.active_statuses + ['CANCELLED']
              ).send(*(exportable_ids.nil? ? [:itself] : [:where, { id: exportable_ids }]))
            ).pluck(:id)
            policy_ids.each do |pol_id|
              policy = Policy.where(id: pol_id).references(:policy_insurables, :policy_users, :integration_profiles).includes(:policy_insurables, :policy_users, :integration_profiles).take
              policy_ip = policy.integration_profiles.find{|ip| ip.integration_id == integration.id }
              next if policy.status == 'CANCELLED' && policy_ip&.configuration&.[]('cancelled') # we've already cancelled it on the remote server, nothing to do
              policy_imported = (policy_ip&.configuration&.[]('history') == 'imported_from_yardi')
              policy_exported = (policy_ip&.configuration&.[]('history') == 'exported_to_yardi' && policy_ip.configuration['present_last_check'] == true)
              policy_document_exported = (policy_ip&.configuration&.[]('exported_to_primary') ? true : false)
              dunny_mcdonesters = policy_imported || (policy_exported && policy_document_exported && (
                (DateTime.parse(policy_ip.configuration['synced_at']) >= ([policy.updated_at] + policy.policy_users.map(&:updated_at) + policy.policy_coverages.map(&:updated_at)).max) rescue false
              )) # WARNING: ideally we would create the policy_hash and compare to the cached one instead of doing this... but for now this works
              next if !universal_export && (dunny_mcdonesters || (!policy_exported && !Policy.active_statuses.include?(policy.status)))
              # create the policy IP if needed
              policy_ip ||= IntegrationProfile.create(
                integration: integration,
                profileable: policy,
                external_context: "policy",
                external_id: policy.number,
                configuration: {
                  'history' => 'not_exported',
                  'synced_at' => (Time.current - 100.years).to_s,
                  'exported_hash' => {}
                }
              )
              prior_configuration = policy_ip.configuration.dup
              export_setup = {
                policy_exported: policy_exported,
                policy_document_exported: policy_document_exported,
                dunny_mcdonesters: dunny_mcdonesters
              }
              # early presence check
              yardi_id = nil
              if early_presence_check
                property_id = policy.primary_insurable&.integration_profiles&.where(integration: integration)&.where("external_context ILIKE 'unit_in_community_%'")&.take&.external_context&.[](18...)
                retrieved = (Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: property_id, policy_number: policy.number)[:parsed_response]
                                                                                       &.dig("Envelope", "Body", "GetInsurancePoliciesResponse", "GetInsurancePoliciesResult", "RenterInsurance", "InsurancePolicy") rescue nil)
                if retrieved.nil?
                  policy_ip.configuration['present_last_check'] = false
                  policy_ip.configuration.delete('policy_id')
                else
                  policy_ip.configuration['present_last_check'] = true
                  policy_ip.configuration['history'] = 'exported_to_yardi'
                  retrieved = retrieved.first if retrieved.class == ::Array
                  yardi_id = retrieved&.[]("PolicyDetails")&.[]("PolicyId")
                  policy_ip.configuration['policy_id'] = yardi_id
                end
                policy_ip.save
              end
              # grab lease stuff
              lease = policy.latest_lease(user_matches: true)
              if lease.nil?
                policy_ip.configuration ||= {}
                expired_matcher = policy.latest_lease(lease_status: 'expired', user_matches: true)
                policy_ip.configuration['export_problem'] = (expired_matcher.nil? ? "No current lease with matching users" : expired_matcher.defunct ? "Lease defunct" : "Lease expired")
                policy_ip.save
                next nil
              end
              lease_users = lease.lease_users.select{|lu| policy.users.pluck(:id).include?(lu.user_id) }
              lease_user_ips = IntegrationProfile.where(integration: integration, profileable: lease_users)
              if lease_user_ips.blank?
                policy_ip.configuration ||= {}
                policy_ip.configuration['export_problem'] = "No matching Yardi lessee records"
                policy_ip.save
                next nil
              end
              used = []
              users_to_export = policy.policy_users.to_a.uniq.map do |pu|
                found = lease_user_ips.find do |lup|
                  !used.include?(lup.external_id) && lup.profileable.user_id == pu.user_id && !lup.external_id.start_with?("was") && (lup.profileable.moved_out_at.nil? || lup.profileable.moved_out_at > Time.current.to_date)
                end || lease_user_ips.find do |lup|
                  !used.include?(lup.external_id) && lup.profileable.user_id == pu.user_id && (lup.profileable.moved_out_at.nil? || lup.profileable.moved_out_at > Time.current.to_date)
                end || lease_user_ips.find do |lup|
                  !used.include?(lup.external_id) && lup.profileable.user_id == pu.user_id && !lup.external_id.start_with?("was")
                end || lease_user_ips.find do |lup|
                  !used.include?(lup.external_id) && lup.profileable.user_id == pu.user_id
                end
                next nil if found.nil?
                preexisting = integration.integration_profiles.where(external_context: "policy_user_for_policy_#{policy.number}", external_id: found.external_id).take
                if preexisting.nil?
                  IntegrationProfile.create(
                    integration: integration,
                    profileable: pu,
                    external_context: "policy_user_for_policy_#{policy.number}",
                    external_id: found.external_id
                  )
                elsif preexisting.profileable_id != pu.id
                  preexisting.update(profileable: pu, configuration: (preexisting.configuration || {}).merge({ 'old_profileable' => "#{preexisting.profileable_type}##{preexisting.profileable_id}" }))
                end
                used.push(found.external_id)
                next found.external_id.start_with?("was") ? nil : {
                  policy_user: pu,
                  lease_user: found.profileable,
                  external_id: found.external_id
                }
              end.compact.uniq
              if users_to_export.blank?
                policy_ip.configuration ||= {}
                policy_ip.configuration['export_problem'] = "No exportable policyholding residents"
                policy_ip.save
                next nil
              end
              policy_priu = users_to_export.find{|u| u[:policy_user].primary }
              lease_priu = users_to_export.find{|u| u[:lease_user].primary }
              # set up export stuff
              priu = integration.configuration['sync']['policy_push']['force_primary_lessee'] ? lease_priu : policy_priu
              if priu.nil?
                policy_ip.configuration ||= {}
                policy_ip.configuration['export_problem'] = (integration.configuration['sync']['policy_push']['force_primary_lessee'] ?
                  "Primary lessee not on policy"
                  : "Primary policyholder not on lease"
                )
                policy_ip.save
                next nil
              end
              if integration.configuration['sync']['policy_push']['push_roommate_policies'] == false && !priu[:lease_user].primary
                policy_ip.configuration ||= {}
                policy_ip.configuration['export_problem'] = "Roommate policy push disabled"
                policy_ip.save
                next nil
              end
              roommate_index = 0
              policy_hash = {
                Customer: {
                  #Identification: users_to_export.map{|u| { "IDValue" => u[:external_id], "IDType" => !u[:external_id].downcase.start_with?("r") ? "Resident ID" : "Roomate#{roommate_index += 1} ID" } },
                  #Identification: users_to_export.map{|u| { "IDValue" => u[:external_id], "IDType" => u[:policy_user].primary ? "Resident ID" : "Roomate#{roommate_index += 1} ID" } },
                  Identification: users_to_export.map{|u| { "IDValue" => u[:external_id], "IDType" => (u == priu ? "Resident ID" : "Roomate#{roommate_index += 1} ID") } },
                  Name: {
                      "FirstName" => (priu[:policy_user] || priu[:lease_user]).user.profile.first_name,
                      "MiddleName" => (priu[:policy_user] || priu[:lease_user]).user.profile.middle_name.blank? ? nil : (priu[:policy_user] || priu[:lease_user]).user.profile.middle_name,
                      "LastName" => (priu[:policy_user] || prui[:lease_user]).user.profile.last_name#,
                      #"Relationship"=> priu[:policy_user].primary ? nil : priu[:policy_user].spouse ? "Spouse" : "Roommate"
                  }.compact
                },
                Insurer: { Name: policy.carrier&.title || policy.out_of_system_carrier_title },
                PolicyNumber: policy.number,
                PolicyTitle: policy.number,
                PolicyDetails: {
                  EffectiveDate: policy.effective_date.to_s,
                  ExpirationDate: policy.expiration_date&.to_s, # WARNING: should we do something else for MPCs?
                  IsRenew: false, # MOOSE WARNING: mark true when renewal... policy.auto_renew,
                  LiabilityAmount: '%.2f' % (policy.get_liability.nil? ? nil : (policy.get_liability.to_d / 100.to_d)) #,
                  #Notes: "GC Verified" #, DISALBRD CAUSSES BROKEENNN
                  #IsRequiredForMoveIn: "false",
                  #IsPMInterestedParty: "true"
                  # WARNING: are these weirdos required? LATER ANSWER: apparently not.
                }.compact
              }
              if policy.status == 'CANCELLED'
                cd = policy.cancellation_date || policy.status_changed_on
                if !cd.nil?
                  cd = policy.effective_date if cd < policy.effective_date
                  cd = policy.expiration_date if cd > policy.expiration_date
                  if cd <= Time.current.to_date
                    policy_hash[:PolicyDetails][:CancelDate] = policy.cancellation_date.to_s
                    policy_hash[:PolicyDetails] = policy_hash[:PolicyDetails].to_a.sort_by do |x|
                      [:EffectiveDate, :ExpirationDate, :IsRenew, :CancelDate, :LiabilityAmount].find_index(x[0])
                    end.to_h
                  end
                end
              end
              # export the policy
              yardi_id ||= policy_ip&.configuration&.[]('policy_id')
              if !policy_exported || policy_hash != policy_ip&.configuration&.[]('exported_hash') || fake_export || universal_export
                # try to grab id if necessary
                #if yardi_id.blank? ALWAYS try to grab it for now, because if it's wrong the dang thing just proceeds to create a new one
                unless early_presence_check
                  property_id = policy.primary_insurable&.integration_profiles&.where(integration: integration)&.where("external_context ILIKE 'unit_in_community_%'")&.take&.external_context&.[](18...)
                  retrieved = (Integrations::Yardi::RentersInsurance::GetInsurancePolicies.run!(integration: integration, property_id: property_id, policy_number: policy.number)[:parsed_response]
                                                                                         &.dig("Envelope", "Body", "GetInsurancePoliciesResponse", "GetInsurancePoliciesResult", "RenterInsurance", "InsurancePolicy") rescue nil)

                  if retrieved.nil?
                    policy_ip.configuration['present_last_check'] = false
                    policy_ip.configuration.delete('policy_id')
                  else
                    policy_ip.configuration['history'] = 'exported_to_yardi'
                    policy_ip.configuration['present_last_check'] = true
                    retrieved = retrieved.first if retrieved.class == ::Array
                    yardi_id = retrieved&.[]("PolicyDetails")&.[]("PolicyId")
                    policy_ip.configuration['policy_id'] = yardi_id
                  end
                end
                #end
                # try to add id to hash
                policy_hash[:PolicyDetails][:PolicyId] = yardi_id if yardi_id
                # export attempt
                if fake_export
                  policy_ip.save
                else
                  event_sequence = []
                  policy_updated = (policy_exported || yardi_id) ? true : false
                  must_cancel = !policy_hash[:PolicyDetails]&.[](:CancelDate).blank?
                  result = Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: property_id, policy_hash: policy_hash, change: policy_updated, cancel: must_cancel)
                  if result[:request].response&.body&.index("Policy already exists in database")
                    event_sequence.push(result[:event].id)
                    policy_updated = true
                    result = Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: property_id, policy_hash: policy_hash, change: true, cancel: must_cancel)
                  end
                  if result[:request].response&.body&.index("could not locate insurance policy based on policy number and tenant identifier")
                    event_sequence.push(result[:event].id)
                    policy_updated = false
                    must_cancel = false # can't cancel on create...
                    result = Integrations::Yardi::RentersInsurance::ImportInsurancePolicies.run!(integration: integration, property_id: property_id, policy_hash: policy_hash, change: false)
                  end
                  if !result[:success]
                    event_sequence.push(result[:event].id)
                    policy_ip.configuration['export_problem'] = "Got failure response (event #{result[:event]&.id})."
                    policy_ip.save
                    ipd = {
                      integration: integration,
                      profileable: policy_ip,
                      external_context: "policy_push_log",
                      external_id: Time.current.to_s + "_" + rand(100000000).to_s,
                      configuration: {
                        success: false,
                        push_type: (must_cancel ? 'cancel' : policy_updated ? "change" : "create"),
                        property_id: property_id,
                        event: result[:event].id,
                        prior_events: event_sequence,
                        yardi_id: yardi_id,
                        policy_hash: policy_hash,
                        export_setup: export_setup,
                        prior_configuration: prior_configuration
                      }
                    }
                    IntegrationProfile.create(ipd)
                    to_return[:policy_export_errors][policy.number] = "Failed to export policy due to error response from Yardi's API (Event id #{result[:event]&.id})."
                    next
                  else
                    respy_fella = (result[:request].response.body.split(":") rescue [])
                    received_yardi_id_preindex = respy_fella.find_index{|x| x == "Policy Id" }
                    if !received_yardi_id_preindex.nil?
                      yardi_id = respy_fella[received_yardi_id_preindex + 1]
                    end
                    if policy_ip.nil?
                      policy_ip = IntegrationProfile.create(
                        integration: integration,
                        profileable: policy,
                        external_context: "policy",
                        external_id: policy.number,
                        configuration: {
                          'policy_id' => yardi_id,
                          'present_last_check' => true,
                          'history' => 'exported_to_yardi',
                          'synced_at' => Time.current.to_s,
                          'exported_hash' => policy_hash
                        }.merge({ policy_updated: policy_updated }.compact)
                      )
                      if(policy_ip.id.nil?)
                        to_return[:policy_export_errors][policy.number] = "Failed to create IntegrationProfile: #{policy_ip.errors.to_h}"
                        next
                      end
                    else
                      policy_ip.configuration['policy_id'] = yardi_id
                      policy_ip.configuration['history'] = 'exported_to_yardi'
                      policy_ip.configuration['synced_at'] = Time.current.to_s
                      policy_ip.configuration['exported_hash'] = policy_hash
                      policy_ip.configuration['cancelled'] = must_cancel
                      policy_ip.configuration.delete('export_problem')
                      policy_ip.save
                    end
                    IntegrationProfile.create(
                      integration: integration,
                      profileable: policy_ip,
                      external_context: "policy_push_log",
                      external_id: Time.current.to_s + "_" + rand(100000000).to_s,
                      configuration: {
                        success: true,
                        push_type: (must_cancel ? "cancel" : policy_updated ? "change" : "create"),
                        property_id: property_id,
                        event: result[:event].id,
                        prior_events: event_sequence,
                        yardi_id: yardi_id,
                        policy_hash: policy_hash,
                        export_setup: export_setup,
                        prior_configuration: prior_configuration
                      }
                    )
                    to_return[:policies_exported][policy.number] = policy
                  end
                end # end unless fake_export
              end # end if !policy_exported...
              if fake_export
                policy_ip.save
                next nil
              end
              if integration.configuration.dig('sync', 'policy_push', 'push_document')
                # revisit policy_document_exported now that we know the priu it should be exported to
                priu = integration.configuration['sync']['policy_push']['force_primary_lessee_for_documents'] ? lease_priu : policy_priu
                next if priu.nil?
                policy_document_exported = policy_ip.configuration['exported_documents_to']&.[](priu[:external_id])&.[]('success')
                next if policy_document_exported
                # upload document
                export_problem = export_policy_document(property_id: property_id, policy: policy, resident_id: priu[:external_id], policy_ip: policy_ip)
                if export_problem.nil?
                  to_return[:policy_documents_exported].push(policy.number)
                elsif export_problem # it will be false if it neither errored nor needed to be run
                  to_return[:policy_export_errors][policy.number] = "Document upload failure: #{export_problem}"
                end
              end # end if !policy_document_exported
            
            end # end export process; we ignore some instead of reporting errors, because they might not be exportable policies and we only found out when we looked at them in detail

          end # end if pull_policies
          
          ##############################################################
          ###################### CLOSING UP SHOP #######################
          ##############################################################
          integration.set_nested(Time.current.to_date.to_s, 'sync', 'syncable_communities', property_id, 'last_sync_p')
          integration.configuration['sync']['sync_history'] ||= []
          integration.configuration['sync']['sync_history'].push({
            'log_format' => '1.0',
            'event_type' => "sync_policies",
            'message' => "Synced policies for Yardi property '#{property_id}'.",
            'timestamp' => Time.current.to_s,
            'errors' => to_return.select{|k,v| k.to_s.end_with?("errors") }
          })
          integration.save
          to_return[:policies_imported] = to_return[:policies_imported]&.keys
          to_return[:policies_updated] = to_return[:policies_updated]&.keys
          to_return[:policies_exported] = to_return[:policies_exported]&.keys
          integration.integration_profiles.create(profileable: integration, external_context: "log_sync_policies", external_id: Time.current.to_i.to_s + "_" + rand(100000000).to_s, configuration: to_return)
          return to_return
          
        end # end method
        
        
      end
    end
  end
end
