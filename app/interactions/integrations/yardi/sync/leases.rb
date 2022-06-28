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
              lease_ip = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: tenant["Id"]).take
              lease = lease_ip.profileable
              # fix basic data
              lease.start_date = Date.parse(tenant["LeaseFrom"])
              lease.end_date = tenant["LeaseTo"].blank? ? nil : Date.parse(tenant["LeaseTo"])
              lease.save if lease.changed?
              # fix profileless users, skipping this lease if we fail (so we can assume below this block that every user has an IP)
              profileless_users = lease.users.where.not(id: IntegrationProfile.where(integration: integration, profileable: lease.users).pluck(:profileable_id))
              next if profileless_users.map do |u|
                ext_id = (da_tenants.find{|dt| dt["Email"] == u.email } || da_tenants.find{|dt| dt['FirstName'] == u.profile.first_name && dt['LastName'] == u.profile.last_name })&.[]('Id')
                next nil if ext_id.nil? # neither success nor failure
                created = (IntegrationProfile.create(
                  integration: integration,
                  profileable: u,
                  external_context: "resident",
                  external_id: ext_id,
                  configuration: {
                    'synced_at' => Time.current.to_s
                  }
                ) rescue nil)
                unless created&.id # failure
                  puts "Failed to create IP for user #{u.id}: #{created&.errors&.to_h}"
                  next true
                end
                next false # success
              end.any?{|x| x == true }
              # remove moved out users MOOSE WARNING: do it!
              # ensure lease user IPs are created, skipping the lease if we fail (so below this block we can assume all LeaseUsers have an IP
              if true #!lease_ip.configuration&.[]('luips_created')
                skip_this = false
                IntegrationProfile.where(integration: integration, external_context: 'resident', profileable: lease.users, external_id: da_tenants.map{|dt| dt["Id"] }).each do |rip|
                  lu = lease.lease_users.find{|lu| lu.user_id == rip.profileable_id }
                  if lu.nil? # just skip for now... shouldn't happen
                    skip_this = true
                    break
                  end
                  unless lu.integration_profiles.where(integration: integration).count > 0
                    created_ip = IntegrationProfile.create(
                      integration: integration,
                      external_context: "lease_user_for_lease_#{tenant["Id"]}",
                      external_id: rip.external_id,
                      profileable: lu,
                      configuration: { 'synced_at' => Time.current.to_s }
                    )
                    if created_ip.id.nil?
                      skip_this = true
                      break # just try again l8urrr
                    end
                  end
                end
                if skip_this
                  next
                else
                  lease_ip.configuration ||= {}
                  lease_ip.configuration['luips_created'] = true
                  lease_ip.configuration['external_data'] = tenant
                  lease_ip.save
                end
              end
              # add new users MOOSE WARNING: do it!
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
                    lessee: (to_create["Id"] == tenant["Id"] || ten["Lessee"] == "Yes")
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
                elsif lu.integration_profiles.where(integration: integration).blank?
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
              # skip create mode stuff since the lease was pre-existing
              next 
            end
            ################### CREATE MODE ######################
            next if tenant_index >= noncreatable_start
            # get the users
            userobjs = ::User.where(email: da_tenants.select{|t| !t["Email"].blank? }.map{|t| t["Email"] }) # (compact to leave out any nil email boyos) we are only using email here because this lease is not in the system; since tenant IDs are lease-specific, no IPs are going to exist with these tenant ids
            userobjs = da_tenants.map.with_index do |ten, ind|
              # get or create the user object
              log_found = true
              userobj = userobjs.find{|u| u.email&.downcase == ten["Email"]&.downcase } # WARNING: what if emails match but names don't....?
              if userobj.nil?
                # try to grab it from the previously-created list, just in case
                userobj = created_by_email[ten["Email"]&.downcase]
                # try to find it by IP
                if userobj.nil? && !user_ip_ids[tenant["Id"]].blank?
                  userobj = ::User.where(id: user_ip_ids[tenant["Id"]]).take
                  found_users[tenant["Id"]] ||= {}
                  found_users[tenant["Id"]][ten["Id"]] = userobj
                end
                # log it as missing
                if userobj.nil?
                  log_found = false if !userobj.nil?
                end
              end
              if !userobj.nil?
                if user_ip_ids[ten["Id"]].nil?
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
                    user_errors[tenant["Id"]][ten["Id"]] = "Failed to create IntegrationProfile for pre-existing user #{ten["FirstName"]} #{ten["LastName"]} (GC id #{userobj.id}): #{created_profile.errors.to_h}"
                    break nil
                  end
                  user_ip_ids[ten["Id"]] = userobj.id
                end
                if log_found
                  found_users[tenant["Id"]] ||= {}
                  found_users[tenant["Id"]][ten["Id"]] = userobj
                end
              else
                break nil if create_user(tenant, ten, created_by_email, created_users, user_errors, user_ip_ids).nil?
              end
              next userobj
            end
            if userobjs.nil? # if here, we already pushed an error message above; skip the rest of this lease since the lease users won't be accurate
              lease_errors[tenant["Id"]] = "Skipped lease due to user import failures."
              next
            end
            # create the lease
            lease = unit.leases.create(start_date: Date.parse(tenant["LeaseFrom"]), end_date: tenant["LeaseTo"].blank? ? nil : Date.parse(tenant["LeaseTo"]), lease_type_id: LeaseType.residential_id, account: integration.integratable)
            if lease.id.nil?
              lease_errors[tenant["Id"]] = "Failed to create Lease: #{lease.errors.to_h}"
              next
            end
            da_tenants.each.with_index do |ten, ind|
              lu = lease.lease_users.create(
                user: userobjs[ind],
                primary: (ind == 0),
                lessee: (ind == 0 || ten["Lessee"] == "Yes")
              )
              IntegrationProfile.create(
                integration: integration,
                external_context: "lease_user_for_lease_#{tenant["Id"]}",
                external_id: ten["Id"],
                profileable: lu,
                configuration: { 'synced_at' => Time.current.to_s }
              )
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
                'external_data' => tenant
              }
            )
            if created_profile.id.nil?
              lease_errors[tenant["Id"]] = "Failed to create IntegrationProfile for lease #{lease.id}: #{created_profile.errors.to_h}"
              next
            end
          end
          # update expired old leases
          in_system = IntegrationProfile.references(:leases).includes(:lease).where(integration: integration, external_context: 'lease', external_id: past_tenants.map{|l| l['Id'] }, profileable_type: "Lease", leases: { status: ['current', 'pending'] })
          in_system.each do |ip|
            rec = past_tenants.find{|l| l['Id'] == ip.external_id }
            l = ip.lease
            found_leases[ip.external_id] = l
            if l.update({ end_date: rec["MoveOut"] || rec["LeaseTo"] }.compact) # MOOSE WARNING: ask yardi if MoveOut might apply only to the primary tenant (in which case the lease doesn't end on this date necessarily...)
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
