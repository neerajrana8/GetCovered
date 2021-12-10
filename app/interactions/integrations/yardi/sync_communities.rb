module Integrations
  module Yardi
    class SyncCommunities < ActiveInteraction::Base
      object :integration
      hash :parsed_response, default: nil
      boolean :sync_units, default: true # true: sync units, false: do not sync units, nil: sync units for new communities only
      boolean :sync_tenants, default: true # true: sync tenants (user and lease/policy data)--will force sync_units true if provided; false: do not sync tenants
      
      # returns thing that says status: error/succes. If success, has :results which is an array of similar things with these statuses:
      #   :already_in_system
      #   :created_integration_profile
      #   :error
      def execute
        # because ActiveIntegration is hideous garbage and `sync_units = true if sync_tenants` will set sync_units to nil for no freaking reason, we have to copy the parameters
        do_sync_units = sync_units
        do_sync_tenants = sync_tenants
        the_response = parsed_response
        # mod sync units
        do_sync_units = true if do_sync_tenants
        # scream if integration is invalid
        return { status: :error, message: "No yardi integration provided" } unless integration
        return { status: :error, message: "Invalid yardi integration provided" } unless integration.provider == 'yardi'
        # perform the call and validate results
        diagnostics = {}
        if the_response.nil?
          result = Integrations::Yardi::GetPropertyConfigurations.run!(integration: integration, diagnostics: diagnostics)
          if result.code != 200
            return { status: :error, message: "Yardi server error (request failed)", event: diagnostics[:event] }
          end
          the_response = result.parsed_response
        end
        properties = the_response.dig("Envelope", "Body", "GetPropertyConfigurationsResponse", "GetPropertyConfigurationsResult", "Properties", "Property")
        if properties.class != ::Array
          properties = [properties] # we do this instead of erroring cause if there's only one response... xml sucks
          #return { status: :error, message: "Yardi server error (invalid response)", event: diagnostics[:event] }
        end
        # prepare to cull already-in-system boyos
        account_id = integration.integratable_type == "Account" ? integration.integratable_id : nil
        already_in_system = IntegrationProfile.references(:insurables).includes(:insurable).where(integration: integration, profileable_type: "Insurable", external_id: properties.map{|p| p["Code"] })
        error_count = 0
        property_results = properties.map do |prop|
          # flee if already in the system
          found = already_in_system.find{|ip| ip.external_id == prop["Code"] }
          next { status: :already_in_system, community: found.insurable, integration_profile: found, yardi_property_data: prop } unless found.nil?
          # get the community property
          address_string = "#{prop["AddressLine1"]}#{prop["AddressLine2"].blank? ? "" : ", #{prop["AddressLine2"]}"}#{prop["AddressLine3"].blank? ? "" : ", #{prop["AddressLine3"]}"}, #{prop["City"]}, #{prop["State"]} #{prop["PostalCode"]}".strip
          community = ::Insurable.get_or_create(
            address: address_string,
            unit: false,
            disallow_creation: false,
            create_if_ambiguous: true,
            created_community_title: prop["MarketingName"].blank? ? nil : prop["MarketingName"],
            communities_only: true,
            account_id: account_id
          )
          case community
            when ::Insurable
              # do nothing, community is already set correctly
            when ::Array
              found = community.select{|c| c.account_id == account_id }
              found.select!{|c| c.title == prop["MarketingName"] } unless found.count <= 1 || prop["MarketingName"].blank?
              unless found.count == 1
                error_count += 1
                next { status: :error, message: "Community address ambiguous", get_or_create_response: community, filtered_get_or_create_response: found, yardi_property_data: prop }
              end
              community = found.first
            when ::Hash
              error_count += 1
              next { status: :error, message: "Community address error", get_or_create_response: community, yardi_property_data: prop }
            when ::NilClass
              error_count += 1
              next { status: :error, message: "Community address nil error", get_or_create_response: nil, yardi_property_data: prop }
          end
          # set up the integration profile
          community.update(account_id: account_id) if community.account_id.nil? && !account_id.nil?
          created_profile = IntegrationProfile.create(
            integration: integration,
            profileable: community,
            external_id: prop["Code"],
            configuration: {
              'synced_at' => Time.current.to_s,
              'external_data' => prop
            }
          )
          if created_profile.id.nil?
            error_count += 1
            next { status: :error, message: "IntegrationProfile save error", record: created_profile, community: community, yardi_property_data: prop }
          end
          next {
            status: :created_integration_profile,
            integration_profile: created_profile,
            community: community
          }
        end
        # handle units and tenants
        tenant_results = nil
        unless do_sync_units == false
          tenant_array = (do_sync_tenants ? [] : nil)
          property_results.each do |pr|
            # skip suckos
            next if pr[:status] == :error
            next if do_sync_units.nil? && pr[:status] == :already_in_system
            # sync dem units
            pr[:unit_sync] = Integrations::Yardi::SyncUnits.run!(integration: integration, community: pr[:community], community_address: pr[:yardi_property_data], property_id: pr[:integration_profile].external_id, do_sync_tenants: do_sync_tenants, tenant_array: tenant_array)
          end
          unless tenant_array.blank?
            tenant_results = Integrations::Yardi::SyncTenants.run!(integration: integration, tenant_array: tenant_array)
          end
        end
        # done
        return { status: :success, results: property_results, error_count: error_count, event: diagnostics[:event], tenant_results: tenant_results }
      end
      
      
      
      
      
    end
    
  end
end
