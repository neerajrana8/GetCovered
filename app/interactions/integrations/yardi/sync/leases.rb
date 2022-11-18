module Integrations
  module Yardi
    module Sync
      class Leases < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
        object :integration
        object :unit, class: Insurable
        array :resident_data
        boolean :update_old, default: false # if you pass true, will run update on past leases that are already in the system; if false, it will ignore them
        
        RESIDENT_STATUSES = {
          'past' => ['Past', 'Canceled', 'Cancelled'],
          'present' => ['Current'],
          'nonfuture' => ['Notice', 'Eviction'],
          'future' => ['Future'],
          'potential' => ['Applicant', 'Wait List'],
          'null' => ['Denied']
        }
        ALLOW_USER_CHANGE = true # true to allow previously imported users that aren't primary leaseholders to change to emailless users if their email appears used by a distinct primary user
        ATTEMPT_TO_USE_EMAIL = false # true to attempt to make email-bearing users with email UIDs, 'primary' to try only for primary leaseholders, false to never try (and if ALLOW_USER_CHANGE is true, users who have logged in & primary leaseholders will have priority in doing so)
        
        def find_or_create_user(tenant, ten)
          # grab the fellow directly if they have already been imported
          primary = (tenant["Id"] == ten["Id"])
          user = IntegrationProfile.where(integration: integration, external_context: "resident", external_id: ten["Id"]).take&.profileable
          return user unless user.nil?
          # figure out if the email is used & if a matching user already exists
          firster = (ten["FirstName"].blank? ? "Unknown" : ten["FirstName"]).strip
          laster = (ten["LastName"].blank? ? "Unknown" : ten["LastName"]).strip
          email_bearer = ten["email"].blank? ? nil : User.where(email: ten["Email"])  # MOOSE WARNING: the query on the following line for users is INCOMPREHENSIBLY HORRIFYING. CHANGE IT, it is so inefficient, omfg...
          candidates = ten["Email"].blank? || (firster == "Unknown" || laster == "Unknown") ? [] : ([email_bearer] + User.references(:profiles).includes(:profile).where.not(email: ten["Email"]).where(profiles: { contact_email: ten["Email"] }).to_a).compact
          candidates.select!{|u| u.profile.first_name&.downcase&.strip == firster.downcase && u.profile.last_name&.downcase&.strip == laster.downcase }
          user = candidates.find{|c| c.integration_profiles.any?{|ip| ip.integration_id == integration.id } } || candidates.first # there should be at most 1 candidate; if not, we could merge them, but instead lets just take the best one and continue
          # create the user if necessary & create the UIP
          ActiveRecord::Base.transaction(requires_new: true) do
            if user.nil?
              # there is no matching user
              if !ten["Email"].blank? && (ATTEMPT_TO_USE_EMAIL == true || (primary && ATTEMPT_TO_USE_EMAIL == 'primary'))
                # we want to use an email
                if !email_bearer.nil?
                  # try to remove the email from the email-bearer
                  unmodifiable = ( (!ALLOW_USER_CHANGE) || (!primary) || (email_bearer.sign_in_count > 0) || (email_bearer.lease_users.where(primary: true).count > 0) || (email_bearer.integration_profiles.where(provider: 'yardi').count == 0) )
                  if unmodifiable == false
                    abandon_attempt = false
                    abandon_attempt = true unless email_bearer.profile.update(contact_email: email_bearer.email)
                    unless abandon_attempt
                      email_bearer.provider = 'altuid'
                      email_bearer.altuid = Time.current.to_i.to_s + rand.to_s
                      email_bearer.uid = email_bearer.altuid
                      abandon_attempt = true unless email_bearer.save
                      unless abandon_attempt
                        email_bearer = nil
                      end
                    end
                  end
                end
                # create our user, using the email if we lacked an email_bearer or were able to remove its email
                user = ::User.create_with_random_password(email: email_bearer.nil? ? ten["Email"] : nil, profile_attributes: {
                  first_name: firster,
                  last_name: laster,
                  middle_name: ten["MiddleName"],
                  contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber"),
                  contact_email: ten["Email"]
                }.compact)
              else
                # we don't even want to use an email
                user = ::User.create_with_random_password(email: nil, profile_attributes: {
                  first_name: firster,
                  last_name: laster,
                  middle_name: ten["MiddleName"],
                  contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber")
                }.merge(ten["Email"].blank? ? {} : { contact_email: ten["Email"] }).compact)
              end
            end
            # freak out on failure
            if user&.id.nil?
              user_errors[tenant["Id"]] ||= {}
              user_errors[tenant["Id"]][ten["Id"]] = "Failed to create user #{ten["FirstName"]} #{ten["LastName"]}: #{user.errors.to_h}"
              user = nil
              raise ActiveRecord::Rollback
            end
            # make sure we construct an IP (which definitely doesn't exist since we early-exited this function if it did)
            ip = IntegrationProfile.create(
              integration: integration,
              profileable: user,
              external_context: "resident",
              external_id: ten["Id"],
              configuration: {
                'synced_at' => Time.current.to_s,
                'post_fix_em' => 'IMPORT'
              }
            )
            if ip.id.nil?
              user_errors[tenant["Id"]] ||= {}
              user_errors[tenant["Id"]][ten["Id"]] = "Failed to create IntegrationProfile for user #{ten["FirstName"]} #{ten["LastName"]}: #{ip.errors.to_h}"
              user = nil
              raise ActiveRecord::Rollback
            end
          end # end transaction
          return user
        end
        
        def fix_ridiculous_swaps(lease, tenant, da_tenants)
          # this has been superseded by roommate sync, but I am leaving the code here for now in case it's needed
          return
          # look for residents whose codes have swapped
          from_system = lease.lease_users.map{|lu| [lu.integration_profiles.take&.external_id, { lease_user: lu, first_name: lu.user.profile.first_name, last_name: lu.user.profile.last_name, middle_name: lu.user.profile.middle_name }] }.to_h
          from_yardi = da_tenants.map do |ten|
            firster = (ten["FirstName"].blank? ? "Unknown" : ten["FirstName"]).strip
            laster = (ten["LastName"].blank? ? "Unknown" : ten["LastName"]).strip
            middler = ten["MiddleName"]
            [ten["Id"], { first_name: ten["FirstName"], last_name: ten["LastName"], middle_name: middler }]
          end.to_h
          # build name-based mapping
          changed = []
          mapping = from_system.map do |eid, system_data|
            next [eid, eid] if from_yardi[eid]&.[](:first_name) == system_data[:first_name] && from_yardi[eid]&.[](:last_name) == system_data[:last_name]
            next [eid,
              from_yardi.select{|yeid, ydata| ydata[:first_name] == system_data[:first_name] && ydata[:last_name] == system_data[:last_name] }.keys&.first
            ]
          end.to_h
          # find flipsy flopsies and flop their ids about
          kings_of_the_sea = []
          mapping.each{|seid, yeid| kings_of_the_sea.push({ seid: seid, yeid: yeid }) if yeid != seid && mapping[yeid] == seid && !kings_of_the_sea.any?{|flipper| flipper[:seid] == yeid && flipper[:yeid] == seid } }
          kings_of_the_sea.each do |flipper|
            next if !from_system.has_key?(flipper[:seid]) || !from_system.has_key?(flipper[:yeid])
            Integrations::Yardi::SwapResidentIds.run!(integration: integration, id1: flipper[:seid], id2: flipper[:yeid])
          end
        end
        
        
        
        
        
        def execute
          # scream if integration is invalid
          return { lease_errors: { 'all' => "No yardi integration provided" } } unless integration
          return { lease_errors: { 'all' => "Invalid yardi integration provided" } } unless integration.provider == 'yardi'
          # set up outputs
          lease_errors = {}
          created_leases = {}
          found_leases = {}
          expired_leases = {}
          user_errors = {}
          created_users = {}
          found_users = {}
          # group resident leases
          resident_datas = resident_data.group_by{|td| td["Status"] }
          future_tenants = (
            (RESIDENT_STATUSES['future'] || []).map{|s| resident_datas[s] || [] }
          ).flatten
          present_tenants = (
            (RESIDENT_STATUSES['present'] || []).map{|s| resident_datas[s] || [] } +
            (RESIDENT_STATUSES['nonfuture'] || []).map{|s| (resident_datas[s] || []).select{|td| td['MoveOut'].blank? || (Date.parse(td['MoveOut']) rescue nil)&.>=(Time.current.to_date) } }
          ).flatten
          past_tenants = (
            (RESIDENT_STATUSES['past'] || []).map{|s| resident_datas[s] || [] } +
            (RESIDENT_STATUSES['nonfuture'] || []).map{|s| (resident_datas[s] || []).select{|td| !td['MoveOut'].blank? && (Date.parse(td['MoveOut']) rescue nil)&.<(Time.current.to_date) } }
          ).flatten
          # grab some variables we shall require in the execution of our noble purpose
          in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: resident_data.map{|l| l['Id'] }, profileable_type: "Lease").pluck(:external_id)
          relevant_tenants = present_tenants + future_tenants
          noncreatable_start = relevant_tenants.count
          relevant_tenants += resident_data.select{|x| !relevant_tenants.include?(x) && in_system.include?(x["Id"]) } if update_old
          created_by_email = {}
          user_ip_ids = IntegrationProfile.where(integration: integration, external_context: 'resident', profileable_type: "User").pluck(:external_id, :profileable_id).to_h
          # mark defunct those leases which the horrific architecture of Yardi's database requires to be removed from their system when they have been superseded
          # MOOSE WARNING: the 'defunct' boolean is a placeholder architectural solution just to get the feature working. ultimately we should be giving these leases a special status and doing something to their IPs...
          IntegrationProfile.where(integration: integration, external_context: 'lease', profileable: unit.leases.where(defunct: false)).where.not(external_id: in_system).each do |lip|
            lip.profileable.update(defunct: true, status: 'expired') 
          end
          # update expired old leases
          in_system_lips = IntegrationProfile.references(:leases).includes(:lease).where(integration: integration, external_context: 'lease', external_id: past_tenants.map{|l| l['Id'] }, profileable_type: "Lease", leases: { status: ['current', 'pending'] })
          in_system_lips.each do |ip|
            rec = past_tenants.find{|l| l['Id'] == ip.external_id }
            l = ip.lease
            found_leases[ip.external_id] = l
            if l.update({ insurable_id: unit.id, end_date: rec["LeaseTo"].blank? ? Time.current.to_date : Date.parse(rec["LeaseTo"]), status: 'expired' }.compact)
              expired_leases[ip.external_id] = l
            else
              lease_errors[ip.external_id] = "Failed to mark lease (GC id #{l.id}) expired: #{l.errors.to_h}"
            end
          end
          in_system_lips = nil
          # create active new and future leases (and run updates)
          relevant_tenants.each.with_index do |tenant, tenant_index|
            da_tenants = [tenant] + (tenant["Roommate"].nil? ? [] : tenant["Roommate"].class == ::Array ? tenant["Roommate"] : [tenant["Roommate"]])
            ################### UPDATE MODE ######################
            if in_system.include?(tenant["Id"])
              lease_ip = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: tenant["Id"]).take
              lease = lease_ip.profileable
              # fix basic data
              lease.insurable_id = unit.id
              lease.start_date = Date.parse(tenant["LeaseFrom"]) unless tenant["LeaseFrom"].blank?
              lease.end_date = Date.parse(tenant["LeaseTo"]) unless tenant["LeaseTo"].blank?
              lease.defunct = false # just in case it was once missing from yardi and now is magically back, for example if it got moved to a different unit. likewise, update statuses in case someone defuncted and expired us previously because we jumped units
              lease.status = 'current' if (lease.end_date.nil? || lease.end_date > Time.current.to_date) && RESIDENT_STATUSES['present'].include?(tenant["Status"])
              lease.status = 'pending' if (lease.end_date.nil? || lease.end_date > Time.current.to_date) && RESIDENT_STATUSES['future'].include?(tenant["Status"]) || RESIDENT_STATUSES['potential'].include?(tenant["Status"])
              lease.sign_date = Date.parse(tenant["LeaseSign"]) unless tenant["LeaseSign"].blank?
              lease.save if lease.changed?
              user_profiles = IntegrationProfile.where(integration: integration, profileable: lease.users).to_a
              # take any tenants that don't correspond to a user, construct/find a user for them, and set up LeaseUser stuff appropriately
              userless_tenants = da_tenants.select{|t| !user_profiles.any?{|up| up.external_id == t["Id"] } }
              failed = false
              userless_tenants.each do |ten|
                # even though this situation should be impossible, try it, since doing so makes our data more robust; note that failures at the right point during trying will actually make the situation possible after all
                luip = IntegrationProfile.where(integration: integration, external_context: "lease_user_for_lease_#{tenant["Id"]}", external_id: ten["Id"]).take
                unless luip.nil?
                  lu = luip.profileable
                  if lu.lease_id != lease.id
                    # WARNING: a serious problem! should NOT happen!
                    luip.delete
                    lu.delete if lu.integration_profiles.reload.count == 0
                  elsif lu.user.nil?
                    lu.integration_profiles.each{|garble| garble.delete }
                    lu.delete
                  else
                    # lu.user is who we seek, the UIP is just incomprehensibly missing
                    created = (IntegrationProfile.create(
                      integration: integration,
                      profileable: lu.user,
                      external_context: "resident",
                      external_id: ten["Id"],
                      configuration: {
                        'synced_at' => Time.current.to_s,
                        'post_fix_em' => true
                      }
                    ) rescue nil)
                    unless created&.id # failure
                      puts "Failed to create IntegrationProfile for user #{u.id}: #{created&.errors&.to_h}"
                      failed = true
                      next
                    end
                    user_profiles.push(created)
                    next
                  end
                end
                # in the rest of this we'll use a user object
                user = nil
                # roommate sync might have promoted a roommate to primary, and will have had to change the primary's tcode to "was_#{date}_#{prev_tcode}"; but if they are still at least a roommate, they might still be here, so check
                lease.lease_users.where.not(id: IntegrationProfile.where(integration: integration, external_context: "lease_user_for_lease_#{tenant["Id"]}", external_id: da_tenants.map{|dt| dt["Id"] }).select(:profileable_id)).each do |lu|
                  if lu.user.profile.contact_email == ten["Email"] && lu.user.profile.first_name&.downcase&.strip == (ten["FirstName"].blank? ? "Unknown" : ten["FirstName"]).strip.downcase && lu.user.profile.last_name&.downcase&.strip == (ten["LastName"].blank? ? "Unknown" : ten["LastName"]).strip.downcase
                    ip = lu.integration_profiles.where(integration: integration, external_context: "lease_user_for_lease_#{tenant["Id"]}").take
                    if ip.nil?
                      user = ip.profileable
                    else
                      IntegrationProfile.where(integration: integration, profileable_type: Integration::YARDI_TCODE_CHANGERS, external_id: ip.external_id).update_all(external_id: ten["Id"])
                      ip.configuration['tcode_changes'] ||= {}
                      ip.configuration['tcode_changes'][Time.current.to_date.to_s] = {
                        old_code: ip.external_id,
                        new_code: ten["Id"],
                        reason: 'postpromotion_match'
                      }
                      ip.external_id = ten["Id"] # gotta do this again here, the update_all won't be reflected in the loaded model
                      unless ip.save
                        failed = true
                        next # MOOSE WARNING: whine in the logs?
                      end
                    end
                    next
                  end
                end
                # since the weird situations weren't the case, continue as normal
                local_failed = false
                ActiveRecord::Base.transaction(requires_new: true) do
                  user ||= find_or_create_user(tenant, ten)
                  if user.nil?
                    local_failed = true
                    raise ActiveRecord::Rollback
                  end
                  lu = lease.lease_users.find{|lu| lu.user_id == user.id && lu.integration_profiles.where(integration: integration, external_context: "lease_user_for_lease_#{tenant["Id"]}").blank? } || lease.lease_users.create(
                    user: user,
                    primary: ten["Id"] == tenant["Id"],
                    lessee: (ten["Id"] == tenant["Id"] || ten["Lessee"] == "Yes"),
                    moved_in_at: (Date.parse(ten["MoveIn"]) rescue nil),
                    moved_out_at: (Date.parse(ten["MoveOut"]) rescue nil)
                  )
                  if lu&.id.nil?
                    local_failed = true
                    raise ActiveRecord::Rollback # MOOSE WARNING: whine in the logs?
                  end
                  luip = IntegrationProfile.create(
                    integration: integration,
                    external_context: "lease_user_for_lease_#{tenant["Id"]}",
                    external_id: ten["Id"],
                    profileable: lu,
                    configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true }
                  )
                  if luip&.id.nil?
                    local_failed = true
                    raise ActiveRecord::Rollback # MOOSE WARNING: whine in the logs?
                  end
                end
                failed ||= local_failed
                next if local_failed # at end of loop but if we add more stuff we don't want to forget this
              end # end ten loop
              if failed
                # at least one user was uncreatable; stop processing the lease further, since we need to be able to assume all users are present in the below code
                next
              end
              # we can assume all tenants have corresponding users & lease users & appropriate IPs, if we're here
              # remove any lease users that don't correspond to tenants
              doomed_lus = lease.lease_users.select{|lu| lu.moved_out_at.nil? && lu.integration_profiles.where(integration: integration, external_context: "lease_user_for_lease_#{tenant["Id"]}", external_id: da_tenants.map{|t| t["Id"] }).count == 0 }
              doomed_lus.each do |dl|
                dl.integration_profiles.each{|ip| ip.delete }
                dl.delete
              end
              # now ensure we update the move in/out dates and primary/lessee statuses
              lease.lease_users.reload.each do |lu|
                ten = da_tenants.find{|t| t["Id"] == lu.integration_profiles.where(integration: integration).take.external_id }
                next if ten.nil? # can't happen but just in case
                moved_in_at = (Date.parse(ten["MoveIn"]) rescue nil)
                moved_out_at = (Date.parse(ten["MoveOut"]) rescue nil)
                primary = (tenant["Id"] == ten["Id"])
                lessee = primary || (ten["Lessee"] == "Yes")
                if (lu.moved_in_at != moved_in_at && !moved_in_at.blank?) || (lu.moved_out_at != moved_out_at && !moved_out_at.blank?) || (lu.primary != primary) || (lu.lessee != lessee)
                  lu.update(moved_in_at: moved_in_at, moved_out_at: moved_out_at, primary: primary, lessee: lessee)
                end
              end
              # handle ridiculous swaps
              fix_ridiculous_swaps(lease, tenant, da_tenants)
              # skip create mode stuff since the lease was pre-existing
              next 
            end
            ################### CREATE MODE ######################
            next if tenant_index >= noncreatable_start
            # create the lease
            ActiveRecord::Base.transaction(requires_new: true) do
              lease = unit.leases.create(
                start_date: Date.parse(tenant["LeaseFrom"]),
                end_date: tenant["LeaseTo"].blank? ? nil : Date.parse(tenant["LeaseTo"]),
                sign_date: tenant["LeaseSign"].blank? ? nil : Date.parse(tenant["LeaseSign"]),
                lease_type_id: LeaseType.residential_id,
                account: integration.integratable
              )
              if lease.id.nil?
                lease_errors[tenant["Id"]] = "Failed to create Lease: #{lease.errors.to_h}"
                next
              end
              da_tenants.each.with_index do |ten, ind|
                userobj = find_or_create_user(tenant, ten)
                if userobj.nil?
                  lease_errors[tenant["Id"]] = "Skipped lease due to user import failures."
                  raise ActiveRecord::Rollback
                end
                lu = lease.lease_users.create(
                  user: userobj,
                  primary: (ind == 0),
                  lessee: (ind == 0 || ten["Lessee"] == "Yes"),
                  moved_in_at: (Date.parse(ten["MoveIn"]) rescue nil),
                  moved_out_at: (Date.parse(ten["MoveOut"]) rescue nil)
                )
                if lu&.id.nil?
                  lease_errors[tenant["Id"]] = "Failed to create Lease due to LeaseUser creation failure for resident '#{ten["Id"]}': #{lu.errors.to_h}"
                  raise ActiveRecord::Rollback
                end
                luip = IntegrationProfile.create!(
                  integration: integration,
                  external_context: "lease_user_for_lease_#{tenant["Id"]}",
                  external_id: ten["Id"],
                  profileable: lu,
                  configuration: { 'synced_at' => Time.current.to_s, 'post_fix_em' => true }
                )
                if luip.id.nil?
                  lease_errors[tenant["Id"]] = "Failed to create Lease due to LeaseUser IntegrationProfile creation failure for resident '#{ten["Id"]}': #{luip.errors.to_h}"
                  raise ActiveRecord::Rollback
                end
              end
              created_leases[tenant["Id"]] = lease
              created_profile = IntegrationProfile.create(
                integration: integration,
                profileable: lease,
                external_context: "lease",
                external_id: tenant["Id"],
                configuration: {
                  'luips_created' => true, # to tell the system we have created lease user integration profiles, since we need to fix those that don't have this property
                  'synced_at' => Time.current.to_s,
                  'external_data' => tenant,
                  'post_fix_em' => true
                }
              )
              if created_profile.id.nil?
                lease_errors[tenant["Id"]] = "Failed to create lease due to IntegrationProfile creation errors: #{created_profile.errors.to_h}"
                raise ActiveRecord::Rollback
              end
            end # end transaction
          end # end lease creation & update logic
          # done
          return({
            lease_errors: lease_errors,
            leases_created: created_leases,
            leases_found: found_leases,
            leases_expired: expired_leases,
            
            user_errors: user_errors,
            users_created: created_users,
            users_found: found_users
          })
        end
        
        
        
        
        
      end
    end
  end
end
