module Integrations
  module Yardi
    module Sync
      class Tenants < ActiveInteraction::Base # MOOSE WARNING: we don't have logic for tenant additions/removals, only full lease additions/removals
        object :integration
        array :tenant_array # array of yardi Resident hashes with an added entry "gc_unit" => some_unit_object. Will be modified.
        
        RESIDENT_STATUSES = {
          'past' => ['Past', 'Canceled', 'Cancelled'],
          'present' => ['Current'],
          'nonfuture' => ['Notice', 'Eviction'],
          'future' => ['Future'],
          'potential' => ['Applicant', 'Wait List'],
          'null' => ['Denied']
        }
        
        # returns thing that says status: error/succes. If success, has :results which is an array of similar things with these statuses:
        #   :already_in_system
        #   :created_integration_profile
        #   :error
        def execute
          # scream if integration is invalid
          return { status: :error, message: "No yardi integration provided" } unless integration
          return { status: :error, message: "Invalid yardi integration provided" } unless integration.provider == 'yardi'
          to_return = { status: :success, results: [], error_count: 0 }
          # group resident leases
          tenant_arrays = tenant_array.group_by{|td| td["Status"] }
          present_tenants = (
            RESIDENT_STATUSES['present'].map{|s| tenant_arrays[s] || [] } +
            RESIDENT_STATUSES['nonfuture'].map{|s| (tenant_arrays[s] || []).select{|td| td['MoveOut'].blank? || (Date.parse(td['MoveOut']) rescue nil)&.>=(Time.current.to_date) } }
          ).flatten
          past_tenants = (
            RESIDENT_STATUSES['past'].map{|s| tenant_arrays[s] || [] } +
            RESIDENT_STATUSES['nonfuture'].map{|s| (tenant_arrays[s] || []).select{|td| !td['MoveOut'].blank? && (Date.parse(td['MoveOut']) rescue nil)&.<(Time.current.to_date) } }
          ).flatten
          # create active new leases
          in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: present_tenants.map{|l| l['Id'] }, profileable_type: "Lease").pluck(:external_id)
          present_tenants.each do |tenant|
            next if in_system.include?(tenant["Id"])
            # get the users
            da_tenants = [tenant] + (tenant["Roommate"].nil? ? [] : tenant["Roommate"].class == ::Array ? tenant["Roommate"] : [tenant["Roommate"]])
            userobjs = ::User.where(email: da_tenants.map{|t| t["Email"] }.compact) # (compact to leave out any nil email boyos) we are only using email here because this lease is not in the system; since tenant IDs are lease-specific, no IPs are going to exist with these tenant ids
            userobjs = da_tenants.map.with_index do |ten, ind|
              # get or create the user object
              userobj = userobjs.find{|u| u.email == ten["Email"] } # MOOSE WARNING: what if emails match but names don't....?
              if userobj.nil?              
                userobj = ::User.create(email: ten["Email"], profile_attributes: {
                  first_name: ten["FirstName"],
                  last_name: ten["LastName"],
                  middle_name: ten["MiddleName"],
                  contact_phone: ten["Phone"]&.select{|x| x["PhoneDescription"] == "cell" || x["PhoneDescription"] == "home" }&.sort_by{|x| { "cell" => 0, "home" => 1 }[x["PhoneDescription"]] || 999 }&.first&.[]("PhoneNumber")
                }.compact)
                unless userobj.id
                  to_return[:results].push({ status: :error, message: "Failed to create user #{ten["FirstName"]} #{ten["LastName"]} (yardi ID ##{ten["Id"]}, lease ID ##{tenant["Id"]}): #{userobj.errors.to_h}" })
                  to_return[:error_count] += 1
                  break nil
                end
                created_profile = IntegrationProfile.create(
                  integration: integration,
                  profileable: userobj,
                  external_context: "tenant_#{tenant["Id"]}",
                  external_id: ten["Id"],
                  configuration: {
                    'synced_at' => Time.current.to_s
                  }
                )
                if created_profile.id.nil?
                  to_return[:error_count] += 1
                  to_return[:results].push({ status: :error, message: "IntegrationProfile save error: #{created_profile.errors.to_h}", record: userobj, yardi_id: ten["Id"] })
                  break nil
                end
              end
              next userobj
            end
            next if userobjs.nil? # if here, we already pushed an error message above in the "unless userobj.id" block; skip the rest of this lease
            # create the lease
            lease = tenant['gc_unit'].leases.create(start_date: Date.parse(tenant["LeaseFrom"]), end_date: tenant["LeaseTo"].blank? ? nil : Date.parse(tenant["LeaseTo"]), lease_type_id: LeaseType::RESIDENTIAL_ID, account: integration.account)
            if lease.id.nil?
              to_return[:results].push({ status: :error, message: "Failed to create lease ##{tenant["Id"]}: #{lease.errors.to_h}" })
              to_return[:error_count] += 1
              next
            end
            da_tenants.each.with_index do |ten, ind|
              lease.users << userobjs[ind] if ind == 0 || ten["Lessee"] == "Yes"
            end
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
              to_return[:error_count] += 1
              to_return[:results].push({ status: :error, message: "IntegrationProfile save error: #{created_profile.errors.to_h}", record: lease, yardi_id: tenant["Id"] })
              next
            end
            to_return[:results].push({ status: :created_lease, lease_id: lease.id, lease_yardi_id: tenant["Id"] })
          end
          # update expired old leases
          in_system = IntegrationProfile.references(:leases).includes(:lease).where(integration: integration, external_context: 'lease', external_id: past_tenants.map{|l| l['Id'] }, profileable_type: "Lease", leases: { status: ['current', 'pending'] })
          in_system.each do |ip|
            rec = past_tenants.find{|l| l['Id'] == ip.external_id }
            l = ip.lease
            if l.update({ end_date: rec["MoveOut"] || rec["LeaseTo"] }.compact) # MOOSE WARNING: ask yardi if MoveOut might apply only to the primary tenant (in which case the lease don't end)
              to_return[:results].push({ status: :marked_lease_expired, lease_id: l.id })
            else
              to_return[:error_count] += 1
              to_return[:results].push({ status: :error, message: "Failed to update lease ##{l.id} to mark as expired; errors: #{l.errors.to_h}" })
            end
          end
          # done
          return to_return
        end
        
        
        
        
        
      end
    end
  end
end
