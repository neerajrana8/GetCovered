module Integrations
  module Yardi
    module Sync
      class Leases < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
        object :integration
        object :unit, class: Insurable
        array :resident_data
        
        RESIDENT_STATUSES = {
          'past' => ['Past', 'Canceled', 'Cancelled'],
          'present' => ['Current'],
          'nonfuture' => ['Notice', 'Eviction'],
          'future' => ['Future'],
          'potential' => ['Applicant', 'Wait List'],
          'null' => ['Denied']
        }
        
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
            RESIDENT_STATUSES['future'].map{|s| resident_data[s] || [] }
          ).flatten
          present_tenants = (
            RESIDENT_STATUSES['present'].map{|s| resident_datas[s] || [] } +
            RESIDENT_STATUSES['nonfuture'].map{|s| (resident_datas[s] || []).select{|td| td['MoveOut'].blank? || (Date.parse(td['MoveOut']) rescue nil)&.>=(Time.current.to_date) } }
          ).flatten
          past_tenants = (
            RESIDENT_STATUSES['past'].map{|s| resident_datas[s] || [] } +
            RESIDENT_STATUSES['nonfuture'].map{|s| (resident_datas[s] || []).select{|td| !td['MoveOut'].blank? && (Date.parse(td['MoveOut']) rescue nil)&.<(Time.current.to_date) } }
          ).flatten
          # create active new and future leases
          created_by_email = {}
          in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: present_tenants.map{|l| l['Id'] }, profileable_type: "Lease").pluck(:external_id)
          (present_tenants + future_tenants).each do |tenant|
            next if in_system.include?(tenant["Id"])
            # get the users
            da_tenants = [tenant] + (tenant["Roommate"].nil? ? [] : tenant["Roommate"].class == ::Array ? tenant["Roommate"] : [tenant["Roommate"]])
            userobjs = ::User.where(email: da_tenants.select{|t| !t["Email"].blank? }.map{|t| t["Email"] }) # (compact to leave out any nil email boyos) we are only using email here because this lease is not in the system; since tenant IDs are lease-specific, no IPs are going to exist with these tenant ids
            userobjs = da_tenants.map.with_index do |ten, ind|
              # get or create the user object
              log_found = true
              userobj = userobjs.find{|u| u.email == ten["Email"] } # MOOSE WARNING: what if emails match but names don't....?
              if userobj.nil?
                userobj = created_by_email[ten["Email"]]
                log_found = false if !userobj.nil?
              end
              if !userobj.nil?
                if log_found
                  found_users[tenant["Id"]] ||= {}
                  found_users[tenant["Id"]][ten["Id"]] = userobj
                end
              else
                userobj = ::User.create_with_random_password(email: ten["Email"], profile_attributes: {
                  first_name: ten["FirstName"],
                  last_name: ten["LastName"],
                  middle_name: ten["MiddleName"],
                  contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber")
                }.compact)
                unless userobj.id
                  user_errors[tenant["Id"]] ||= {}
                  user_errors[tenant["Id"]][ten["Id"]] = "Failed to create user #{ten["FirstName"]} #{ten["LastName"]}: #{userobj.errors.to_h}"
                  break nil
                end
                created_by_email[ten["Email"]] = userobj unless ten["Email"].blank?
                created_users[tenant["Id"]] ||= {}
                created_users[tenant["Id"]][ten["Id"]] = userobj
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
                  break nil
                end
              end
              next userobj
            end
            if userobjs.nil? # if here, we already pushed an error message above in the "unless userobj.id" block; skip the rest of this lease
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
              lease.lease_users.create(
                user: userobjs[ind],
                primary: (ind == 0),
                lessee: (ind == 0 || ten["Lessee"] == "Yes")
              )
            end
            created_leases[tenant["Id"]] = lease
            created_profile = IntegrationProfile.create(
              integration: integration,
              profileable: lease,
              external_context: "lease",
              external_id: tenant["Id"],
              configuration: {
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
