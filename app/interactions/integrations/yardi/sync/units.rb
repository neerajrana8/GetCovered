module Integrations
  module Yardi
    module Sync
      class Units < ActiveInteraction::Base
        object :integration
        object :community, class: Insurable
        string :property_id
        hash :community_address, default: nil
        boolean :sync_tenants, default: true # true: sync tenants, false: don't sync tenants
        array :tenant_array, default: nil # pass an array to have it filled with tenant data rather than processing internally
        hash :parsed_response, default: nil
        
        # returns thing that says status: error/succes. If success, has :results which is an array of similar things with these statuses:
        #   :already_in_system
        #   :created_integration_profile
        #   :error
        def execute
          # escape from ActiveInteraction's hideous garbage bugs (see sync_communities.rb for details)
          comm = community
          comm_address = community_address
          prop_id = property_id
          do_sync_tenants = sync_tenants
          the_tenant_array = tenant_array
          the_response = parsed_response
          # scream if integration is invalid
          return { status: :error, message: "No yardi integration provided" } unless integration
          return { status: :error, message: "Invalid yardi integration provided" } unless integration.provider == 'yardi'
          # hashify comm address
          if comm_address.nil?
            comm_address = comm.primary_address
            comm_address = {
              "AddressLine1" => [comm_address.street_number, comm_address.street_name].select{|v| !v.blank? }.join(" "),
              "City" => comm_address.city,
              "State" => comm_address.state,
              "PostalCode" => comm_address.zip_code
            }
          end
          # perform the call and validate results
          diagnostics = {}
          if the_response.nil?
            result = Integrations::Yardi::RentersInsurance::GetUnitConfiguration.run!(integration: integration, property_id: prop_id, diagnostics: diagnostics)
            if result.code != 200
              return { status: :error, message: "Yardi server error (request failed)", event: diagnostics[:event] }
            end
            the_response = result.parsed_response
          end
          properties = the_response.dig("Envelope", "Body", "GetUnitConfigurationResponse", "GetUnitConfigurationResult", "Units", "Unit")
          if properties.class != ::Array
            properties = [properties] # we do this instead of erroring cause if there's only one response... xml sucks
            #return { status: :error, message: "Yardi server error (invalid response)", event: diagnostics[:event] }
          end
          # prepare to cull already-in-system boyos
          account_id = integration.integratable_type == "Account" ? integration.integratable_id : nil
          already_in_system = IntegrationProfile.references(:insurables).includes(:insurable).where(integration: integration, profileable_type: "Insurable", external_context: "unit_in_comm_#{prop_id}", external_id: properties.map{|p| p["UnitId"] })
          error_count = 0
          property_results = properties.map do |prop|
            # flee if already in the system
            found = already_in_system.find{|ip| ip.external_id == prop["UnitId"] }
            next { status: :already_in_system, unit: found.insurable, integration_profile: found, yardi_property_data: prop } unless found.nil?
            # get the unit
            parent_insurable = nil
            unit = nil
            if prop["City"] == comm_address["City"] && prop["Address"].start_with?(comm_address["AddressLine1"]) && prop["State"] == comm_address["State"] && prop["PostalCode"] == comm_address["PostalCode"]
              # the unit belongs directly to the comm
              parent_insurable = comm
              possible_unit_title = prop["Address"][comm_address.length..-1].strip
              unit = comm.units.find{|u| u.title == possible_unit_title } ||
                     comm.units.find{|u| u.title == prop["UnitId"] } ||
                     ::Insurable.get_or_create(
                address: "#{comm_address["AddressLine1"]}, #{prop["City"]}, #{prop["State"]} #{prop["PostalCode"]}",
                unit: possible_unit_title.blank? ? true : possible_unit_title,
                titleless: possible_unit_title.blank?,
                disallow_creation: false,
                insurable_id: parent_insurable.id,
                create_if_ambiguous: true,
                account_id: account_id
              )
              unless unit.class == ::Insurable
                error_count += 1
                next { status: :error, message: "Unable to create unit in comm", get_or_create_response: unit, yardi_property_data: prop }
              end
            else
              # the unit belongs to a sub-building
              building = ::Insurable.get_or_create(
                address: "#{prop["Address"].chomp("UnitId").strip}, #{prop["City"]}, #{prop["State"]} #{prop["PostalCode"]}",
                unit: false,
                disallow_creation: false,
                insurable_id: comm.id,
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
              external_context: "unit_in_comm_#{prop_id}",
              external_id: prop["UnitId"],
              configuration: {
                'synced_at' => Time.current.to_s,
                'external_data' => prop
              }
            )
            if created_profile.id.nil?
              error_count += 1
              next { status: :error, message: "IntegrationProfile save error", record: created_profile, comm: comm, yardi_property_data: prop }
            end
            next {
              status: :created_integration_profile,
              integration_profile: created_profile,
              unit: unit,
              yardi_property_data: prop
            }
          end
          # handle tenant information
          tenant_info = !do_sync_tenants ? [] : property_results.map do |pr|
            next if pr[:status] == :error || pr[:yardi_property_data]["Resident"].blank?
            (pr[:yardi_property_data]["Resident"].class == ::Array ? pr[:yardi_property_data]["Resident"] : [pr[:yardi_property_data]["Resident"]]).map do |res|
              res["gc_unit"] = pr[:unit]
            end
          end.compact.flatten(1)
          if the_tenant_array
            the_tenant_array.concat(tenant_info)
          elsif do_sync_tenants
            tenant_info = Integrations::Yardi::Sync::Tenants.run!(integration: integration, tenant_array: tenant_info)
          end
          # done
          return { status: :success, results: property_results, error_count: error_count, event: diagnostics[:event] }.merge(do_sync_tenants && the_tenant_array.nil? ? { tenant_results: tenant_info } : {})
        end
        
        
        
        
        
      end
    end
  end
end
