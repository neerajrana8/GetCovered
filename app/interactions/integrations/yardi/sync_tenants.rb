module Integrations
  module Yardi
    class SyncTenants < ActiveInteraction::Base
      object :integration
      array :tenant_array # array of yardi Resident hashes with an added entry "gc_unit" => some_unit_object. Will be modified.
      bool :only_update_existing, default: false
      
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
        present_tenants = (RESIDENT_STATUSES['present'] + RESIDENT_STATUSES['nonfuture'].select{|td| td['MoveOut'].blank? || (Date.parse(td['MoveOut']) rescue nil)&.>=(Time.current.to_date) }).map{|s| tenant_arrays[s] }.flatten
        past_tenants = (RESIDENT_STATUSES['past'] + RESIDENT_STATUSES['nonfuture'].select{|td| !td['MoveOut'].blank? && (Date.parse(td['MoveOut']) rescue nil)&.<(Time.current.to_date) }).map{|s| tenant_arrays[s] }.flatten
        #   ...new leases
        in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: present_tenants.map{|l| l['Id'] }, profileable_type: "Lease").pluck(:external_id)
        present_tenants.each do |tenant|
          next if in_system.include?(tenant["Id"])
          # create the user and lease # MOOSE WARNING do this
          
          
          
          
          to_return[:results].push({ status: :created_lease, ... }) # MOOSE WARNING add more data
        end
        #  ...old leases
        in_system = IntegrationProfile.where(integration: integration, external_context: 'lease', external_id: past_tenants.map{|l| l['Id'] }, profileable_type: "Lease")
        Lease.where(id: in_system.map{|is| is.profileable_id }, status: 'current').each do |l| # MOOSE WARNING: add end date modifications?
          if l.update(status: 'expired')
            to_return[:results].push({ status: :marked_lease_expired, lease_id: l.id })
          else
            to_return[:error_count] += 1
            to_return[:results].push({ status: :error, message: "Failed to update lease ##{l.id} to mark as expired; errors: #{l.errors.to_h}" })
          end
        end
        
        
        
        
        
        
        
        
        
        # done
        #return { success: true, results: by_id.values, error_count: error_count }
      end
      
      
      
      
      
    end
    
  end
end
