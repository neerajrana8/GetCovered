module Integrations
  module Yardi
    class SyncUnits < ActiveInteraction::Base
      object :integration
      object :community
      string :property_id
      boolean :sync_tenants, default: true # true: sync tenants, false: don't sync tenants
      hash :community_address, default: nil
      array :tenant_array, default: nil # pass an array to have it filled with tenant data rather than processing internally
      
      # returns thing that says status: error/succes. If success, has :results which is an array of similar things with these statuses:
      #   :already_in_system
      #   :created_integration_profile
      #   :error
      def execute
        # escape from ActiveInteraction's hideous garbage bugs (see sync_communities.rb for details)
        
        # scream if integration is invalid
        return { status: :error, message: "No yardi integration provided" } unless integration
        return { status: :error, message: "Invalid yardi integration provided" } unless integration.provider == 'yardi'
        # hashify community address
        if community_address.nil?
          community_address = community.primary_address
          community_address = {
            "AddressLine1" => [community_address.street_number, community_address.street_name].select{|v| !v.blank? }.join(" "),
            "City" => community_address.city,
            "State" => community_address.state,
            "PostalCode" => community_address.zip_code
          }
        end
        # perform the call and validate results
        diagnostics = {}
        if parsed_response.nil?
          result = Integrations::Yardi::GetUnitConfiguration.run!(integration: integration, property_id: property_id, diagnostics: diagnostics)
          if result.code != 200
            return { status: :error, message: "Yardi server error (request failed)", event: diagnostics[:event] }
          end
          parsed_response = result.parsed_response
        end
        properties = parsed_response.dig("Envelope", "Body", "GetUnitConfigurationResponse", "GetUnitConfigurationResult", "Units", "Unit")
        if properties.class != ::Array
          properties = [properties] # we do this instead of erroring cause if there's only one response... xml sucks
          #return { status: :error, message: "Yardi server error (invalid response)", event: diagnostics[:event] }
        end
        # prepare to cull already-in-system boyos
        account_id = integration.integratable_type == "Account" ? integration.integratable_id : nil
        already_in_system = IntegrationProfile.where(integration: integration, profileable_type: "Insurable", external_id: properties.map{|p| p["UnitId"] })
        error_count = 0
        property_results = properties.map do |prop|
          # flee if already in the system
          found = already_in_system.find{|ip| ip.external_id == prop["UnitId"] }
          next { status: :already_in_system, unit: found.profileable, integration_profile: found } unless found.nil?
          # get the unit
          parent_insurable = nil
          unit = nil
          if prop["City"] == community_address["City"] && prop["Address"].start_with?(community_address["AddressLine1"]) && prop["State"] == community_address["State"] && prop["PostalCode"] == community_address["PostalCode"]
            # the unit belongs directly to the community
            parent_insurable = community
            possible_unit_title = prop["Address"][community_address.length..-1].strip
            unit = community.units.find{|u| u.title == possible_unit_title } ||
                   community.units.find{|u| u.title == prop["UnitId"] } ||
                   ::Insurable.get_or_create(
              address: "#{community_address["AddressLine1"]}, #{prop["City"]}, #{prop["State"]} #{prop["PostalCode"]}",
              unit: possible_unit_title.blank? ? true : possible_unit_title,
              titleless: possible_unit_title.blank?,
              disallow_creation: false,
              insurable_id: parent_insurable.id,
              create_if_ambiguous: true,
              account_id: account_id
            )
            unless unit.class == ::Insurable
              error_count += 1
              next { status: :error, message: "Unable to create unit in community", get_or_create_response: unit, yardi_property_data: prop }
            end
          else
            # the unit belongs to a sub-building
            building = ::Insurable.get_or_create(
              address: "#{prop["Address"].chomp("UnitId").strip}, #{prop["City"]}, #{prop["State"]} #{prop["PostalCode"]}",
              unit: false,
              disallow_creation: false,
              insurable_id: community.id,
              create_if_ambiguous: true,
              account_id: account_id
            )
            unless building.class == ::Insurable
              error_count += 1
              next { status: :error, message: "Unable to create building", get_or_create_response: building, yardi_property_data: prop }
            end
            # create the unit
            parent_insurable = building
            unit = ::Insurable.get_or_create(
              address: "#{prop["Address"].chomp(prop["UnitId"]).strip}, #{prop["City"]}, #{prop["State"]} #{prop["PostalCode"]}",
              unit: prop["Address"].end_with?(prop["UnitId"]) ? prop["UnitId"] : true,
              titleless: !prop["Address"].end_with?(prop["UnitId"]),
              disallow_creation: false,
              insurable_id: building.id,
              create_if_ambiguous: true,
              account_id: account_id
            )
            unless unit.class == ::Insurable
              error_count += 1
              next { status: :error, message: "Unable to create unit in building", get_or_create_response: unit, yardi_property_data: prop }
            end
          end
          # set up the integration profile
          parent_insurable.update(account_id: account_id) if parent_insurable.account_id.nil? && !account_id.nil?
          unit.update(account_id: account_id) if unit.account_id.nil? && !account_id.nil?
          created_profile = IntegrationProfile.create(
            integration: integration,
            profileable: unit,
            external_context: "unit_in_community_#{property_id}",
            external_id: prop["UnitId"],
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
            unit: unit
          }
        end
        # handle tenant information
        tenant_info = !sync_tenants ? {} : property_results.map do |pr|
          next if pr[:status] == :error || pr[:yardi_property_data]["Resident"].blank?
          (pr[:yardi_property_data]["Resident"].class == ::Array ? pr[:yardi_property_data]["Resident"] : [pr[:yardi_property_data]["Resident"]]).map do |res|
            res["gc_unit"] = pr[:unit]
          end
        end.compact.flatten(1)
        if tenant_array
          tenant_array.concat(tenant_info)
        elsif sync_tenants
          tenant_info = Integrations::Yardi::SyncUnits.run!(integration: integration, tenant_array: tenant_info)
        end
        # done
        return { status: :success, results: property_results, error_count: error_count, event: diagnostics[:event] }.merge(sync_tenants && tenant_array.nil? ? { tenant_results: tenant_info } : {})
      end
      
      
      
      
      
    end
    
  end
end
