module Integrations
  module Yardi
    class SyncTenants < ActiveInteraction::Base
      object :integration
      array :tenant_array # array of yardi Resident hashes with an added entry "gc_unit" => some_unit_object. Will be modified.
      bool :only_update_existing, default: false
      
      RESIDENT_STATUSES = {
        'past' => ['Eviction', 'Past', 'Cancelled'],
        'present' => ['Current'],
        'future' => ['Future'],
        'potential' => ['Applicant'],
        'null' => [] # MOOSE WARNING: might want to move cancelled to here
      }
      
      # returns thing that says status: error/succes. If success, has :results which is an array of similar things with these statuses:
      #   :already_in_system
      #   :created_integration_profile
      #   :error
      def execute
        # scream if integration is invalid
        return { status: :error, message: "No yardi integration provided" } unless integration
        return { status: :error, message: "Invalid yardi integration provided" } unless integration.provider == 'yardi'
        # filter out residents
        tenant_array.select! do |td| # "tenant data"
          # docs say td["Status"] can be Current, Notice, Eviction, Future, Past, Cancelled
          # test data also shows others like "Applicant"
          # MOOSE WARNING: filter out statuses here. we just want current and former
          RESIDENT_STATUSES['past'].include?(td["Status"]) || RESIDENT_STATUSES['present'].include?(td["Status"])
        end
        # handle residents
        by_id = tenant_array.group_by{|td| td["Id"] }
        ips = IntegrationProfile.where(integration: integration, external_context: "user", external_id: by_id.keys, profileable_type: "User").order(external_id: :asc) # MOOSE WARNING: here & elsewhere, use eager loading (here for the attached User)
        ips.each do |ip|
          resident_hash = by_id[ip.external_id]
          next if resident_hash.nil? # should be impossible but let's prevent unlikely car crashes where possible
          resident_hash["gc_done"] = true
          # MOOSE WARNING DO IT HERE
          # update already-present, integrated resident
        end
        preexisting_users = User.where(email: by_id.values.map{|td| td["gc_done"] ? nil : td["Email"].blank? ? nil : td["Email"].downcase }.compact
        by_id.transform_values! do |td|
          next td if td["gc_done"]
          next nil if RESIDENT_STATUSES['past'].include?(td['Status']) || RESIDENT_STATUSES['future'].include?(td['Status']) || RESIDENT_STATUSES['potential'].include?(td['Status']) || RESIDENT_STATUSES['null'].include?(td['Status']) # leave these cheap checks in case we let some of these statuses through; toherwise, only past needs to be thrown out here
          user = preexisting_users.find{|u| u.email == td["Email"] }
          if user
            # MOOSE WARNING update already-present, unintegrated resident here
          else
            # MOOSE WARNING create new user here
          end
        end
        
        
        
        
        # done
        #return { success: true, results: by_id.values, error_count: error_count }
      end
      
      
      
      
      
    end
    
  end
end
