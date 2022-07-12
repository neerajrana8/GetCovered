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
          email_bearer = ten["email"].blank? ? nil : User.where(email: ten["Email"])
          candidates = ten["Email"].blank? || (firster == "Unknown" || laster == "Unknown") ? [] : [email_bearer] + User.references(:profiles).includes(:profile).where.not(email: ten["Email"]).where(profiles: { contact_email: ten["Email"] }).to_a.compact
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
                  unmodifiable = !ALLOW_USER_CHANGE || !primary || user.sign_in_count > 0 || user.lease_users.where(primary: true).count > 0 || user.integration_profiles.where(provider: 'yardi').count == 0
                  unless unmodifiable
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
        
        def create_user(tenant, ten, created_by_email, created_users, user_errors, user_ip_ids, create_ip: true) # tenant is a t-code resident hash, ren is either the same hash or a roommate hash from inside it
          userobj = ::User.create_with_random_password(email: ten["Email"], profile_attributes: {
            first_name: ten["FirstName"],
            last_name: ten["LastName"],
            middle_name: ten["MiddleName"],
            contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber")
          }.compact)
          unless userobj.id
            user_errors[tenant["Id"]] ||= {}
            user_errors[tenant["Id"]][ten["Id"]] = "Failed to create user #{ten["FirstName"]} #{ten["LastName"]}: #{userobj.errors.to_h}"
            return nil
          end
          created_by_email[ten["Email"]&.downcase] = userobj unless ten["Email"].blank?
          created_users[tenant["Id"]] ||= {}
          created_users[tenant["Id"]][ten["Id"]] = userobj
          if create_ip
            created_profile = IntegrationProfile.create(
              integration: integration,
              profileable: userobj,
              external_context: "resident",
              external_id: ten["Id"],
              configuration: {
                'synced_at' => Time.current.to_s
              }
            )
            if created_profile.id.nil?
              user_errors[tenant["Id"]] ||= {}
              user_errors[tenant["Id"]][ten["Id"]] = "Failed to create IntegrationProfile for user #{ten["FirstName"]} #{ten["LastName"]} (GC id #{userobj.id}): #{created_profile.errors.to_h}"
              return nil
            else
              user_ip_ids[ten["Id"]] = created_profile.id
            end
          end
          return userobj
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
          # create active new and future leases
          in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: resident_data.map{|l| l['Id'] }, profileable_type: "Lease").pluck(:external_id)
          relevant_tenants = present_tenants + future_tenants
          noncreatable_start = relevant_tenants.count
          relevant_tenants += resident_data.select{|x| !relevant_tenants.include?(x) && in_system.include?(x["Id"]) } if update_old
          created_by_email = {}
          user_ip_ids = IntegrationProfile.where(integration: integration, external_context: 'resident', profileable_type: "User").pluck(:external_id, :profileable_id).to_h
          relevant_tenants.each.with_index do |tenant, tenant_index|
            da_tenants = [tenant] + (tenant["Roommate"].nil? ? [] : tenant["Roommate"].class == ::Array ? tenant["Roommate"] : [tenant["Roommate"]])
            ################### UPDATE MODE ######################
            if in_system.include?(tenant["Id"])
=begin
              lease_ip = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: tenant["Id"]).take
              lease = lease_ip.profileable
              # fix basic data
              lease.start_date = Date.parse(tenant["LeaseFrom"])
              lease.end_date = tenant["LeaseTo"].blank? ? nil : Date.parse(tenant["LeaseTo"])
              lease.save if lease.changed?
              # fix profileless users, skipping this lease if we fail (so we can assume below this block that every user has an IP)
  #####
              user_profiles = IntegrationProfile.where(integration: integration, profileable: lease.users).to_a
              profileless_users = lease.users.select{|u| !user_profiles.any?{|up| up.profileable_id == u.id } }
              userless_tenants = da_tenants.select{|t| !user_profiles.any?{|up| up.external_id == t["Id"] } }
              
              next if profileless_users.map do |u|
                ext_id = userless_tenants.find{|ut| ut["FirstName"]&.strip&.downcase == u.profile.first_name&.strip&.downcase && ut["LastName"]&.strip&.downcase == u.profile.last_name&.strip&.downcase }&.[]("Id")
                next false if ext_id.nil? # MOOSE WARNING: change to next nil if you want to allow continuation if someone has no match
                created = (IntegrationProfile.create(
                  integration: integration,
                  profileable: u,
                  external_context: "resident",
                  external_id: ext_id,
                  configuration: {
                    'synced_at' => Time.current.to_s,
                    'post_fix_em' => true
                  }
                ) rescue nil)
                unless created&.id # failure
                  puts "Failed to create IntegrationProfile for user #{u.id}: #{created&.errors&.to_h}"
                  next false
                end
                user_profiles.push(created)
                userless_tenants.select!{|ut| ut["Id"] != ext_id }
                next u # success
              end.compact.map{|u| profileless_users.delete(u) unless u == false; u }.any?{|x| x == false }
              
              # remove moved out users MOOSE WARNING: do it!
              
              # ensure lease user IPs are created, skipping the lease if we fail (so below this block we can assume all LeaseUsers have an IP
              luip_fix_failed = false
              luips = integration.integration_profiles.where(profileable: lease.lease_users)
              lease.lease_users.select do |lu|
                luip = luips.find{|luip| luip.profileable == lu }
                if luip.nil?
                  up = user_profiles.find{|up| up.profileable_id == lu.user_id }
                  created_ip = IntegrationProfile.create(
                    integration: integration,
                    external_context: "lease_user_for_lease_#{tenant["Id"]}",
                    external_id: up.external_id,
                    profileable: lu,
                    configuration: { 'synced_at' => Time.current.to_s }
                  )
                  if created_ip.id.nil?
                    luip_fix_failed = true
                    break # we will just try again l8urr, but MOOSE WARNING you may want to scream about the error
                  end
                end
              end
              if luip_fix_failed
                next
              end
              lease_ip.configuration ||= {}
              lease_ip.configuration['luips_created'] = true
              lease_ip.configuration['external_data'] = tenant
              lease_ip.save
              
              # add new users

              IntegrationProfile.where(integration: integration, external_context: 'resident', profileable: lease.users, external_id: da_tenants.map{|dt| dt["Id"] }).each do |rip|
              end
  #####
              
              
              # add new users
              ips = IntegrationProfile.where(integration: integration, external_context: 'resident', profileable: lease.users, external_id: da_tenants.map{|dt| dt["Id"] })
              da_tenants.select{|t| !ips.any?{|i| i.external_id == t["Id"] } }.each do |to_create|
                # find or create the user
                userobj = to_create["Email"].blank? ? nil : User.where(email: to_create["Email"]).take
                if userobj.nil?
                  userobj = create_user(tenant, to_create, created_by_email, created_users, user_errors, user_ip_ids, create_ip: false)
                  next if userobj.nil?
                end
                # create the lease user IP
                lu = lease.lease_users.find{|larse_yarsarr| larse_yarsarr.user_id == userobj.id }
                if lu.nil?
                  lu = lease.lease_users.create(
                    user: userobj,
                    primary: to_create["Id"] == tenant["Id"],
                    lessee: (to_create["Id"] == tenant["Id"] || to_create["Lessee"] == "Yes")
                  )
                  if lu&.id.nil?
                    next
                  end
                  ip = IntegrationProfile.create(
                    integration: integration,
                    external_context: "lease_user_for_lease_#{tenant["Id"]}",
                    external_id: to_create["Id"],
                    profileable: lu,
                    configuration: { 'synced_at' => Time.current.to_s }
                  )
                  if ip&.id.nil?
                    next
                  end
                elsif lu.integration_profiles.where(integration: integration).reload.blank?
                  created_ip = IntegrationProfile.create(
                    integration: integration,
                    external_context: "lease_user_for_lease_#{tenant["Id"]}",
                    external_id: to_create['Id'],
                    profileable: lu,
                    configuration: { 'synced_at' => Time.current.to_s }
                  )
                  if created_ip.id.nil?
                    next # try again next time, we want all our ducks in a row before the user's IP is created
                  end
                end
                # create the IP (which we know doesn't exist because we filtered precisely for guys who lacked one)
                unless userobj.nil?
                  created_ip = IntegrationProfile.create(
                    integration: integration,
                    profileable: userobj,
                    external_context: "resident",
                    external_id: to_create["Id"],
                    configuration: {
                      'synced_at' => Time.current.to_s
                    }
                  )
                  if created_ip.id.nil?
                    user_errors[tenant["Id"]] ||= {}
                    user_errors[tenant["Id"]][to_create["Id"]] = "Failed to create IntegrationProfile for user #{to_create["FirstName"]} #{to_create["LastName"]} (GC id #{userobj.id}): #{created_ip.errors.to_h}"
                    return nil
                  else
                    user_ip_ids[to_create["Id"]] = created_ip.id
                  end
                end
              end
=end
              # skip create mode stuff since the lease was pre-existing
              next 
            end
            ################### CREATE MODE ######################
            next if tenant_index >= noncreatable_start
            # create the lease
            ActiveRecord::Base.transaction(requires_new: true) do
              lease = unit.leases.create(start_date: Date.parse(tenant["LeaseFrom"]), end_date: tenant["LeaseTo"].blank? ? nil : Date.parse(tenant["LeaseTo"]), lease_type_id: LeaseType.residential_id, account: integration.integratable)
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
                  lessee: (ind == 0 || ten["Lessee"] == "Yes")
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
          end
          # update expired old leases
          in_system = IntegrationProfile.references(:leases).includes(:lease).where(integration: integration, external_context: 'lease', external_id: past_tenants.map{|l| l['Id'] }, profileable_type: "Lease", leases: { status: ['current', 'pending'] })
          in_system.each do |ip|
            rec = past_tenants.find{|l| l['Id'] == ip.external_id }
            l = ip.lease
            found_leases[ip.external_id] = l
            if l.update({ end_date: rec["LeaseTo"] }.compact) # MOOSE WARNING: ask yardi if MoveOut might apply only to the primary tenant (in which case the lease doesn't end on this date necessarily...)
              expired_leases[ip.external_id] = l
            else
              lease_errors[ip.external_id] = "Failed to mark lease (GC id #{l.id}) expired: #{l.errors.to_h}"
            end
          end
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
