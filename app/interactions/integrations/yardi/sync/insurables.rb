module Integrations
  module Yardi
    module Sync
      class Insurables < ActiveInteraction::Base
        object :integration
        string :property_list_id, default: nil
        array :property_ids, default: nil
        boolean :insurables_only, default: false # disabled roommate & lease sync (policy sync is never invoked by insurables sync)
        boolean :efficiency_mode, default: false
        
        def account_id
          integration.integratable_id
        end
                
        def should_import_community(property_id)
          return case property_ids
            when ::String;    property_ids == property_id # WARNING: can't actually pass a string atm because ActiveIntegration is stupid...
            when ::Array;     property_ids.include?(property_id)
            else;             integration.configuration['sync']['syncable_communities'][property_id]&.[]('enabled') == true
          end
        end

        def fixaddr(markname, unitid, addr)
          return addr if addr.blank?
          if !['0','1','2','3','4','5','6','7','8','9'].include?(addr[0])
            addr = addr.split(markname).join(" ").gsub("  ", " ").strip
          end
          addr = addr.gsub(" ", "  ")
          return addr if addr.blank?
          uid_parts = unitid.split("-")
          uid_lasto = "#{uid_parts.last}"
          uid_lasto = uid_lasto[1..-1] while uid_lasto[0] && uid_lasto[0] == "0"
          splat = addr.split(" ")
          if splat[-3] && ["Apt", "Apr", "Apartment", "Unit", "Apt.", "Apr.", "Ste.", "Ste", "Suite", "Room", "Rm", "Rm."].include?(splat[-2])
            if !splat[-3].end_with?(",")
              splat[-3] += ","
              splat[-2] = "Apt" if splat[-2] == "Apr" || splat[-2] == "Apr."
              addr = splat.join(" ")
            elsif splat[-2] == "Apr" || splat[-2] == "Apr."
              splat[-2] = "Apt"
              addr = splat.join(" ")
            end
          elsif splat[-2] && (splat[-1] == unitid || splat[-1] == uid_parts.last || splat[-1] == uid_lasto) && !splat[-2]&.end_with?(',')
            splat[-2] += ', Apt'
            addr = splat.join(" ")
          end
          
          return addr
        end

        def after_address_hacks(addr) # takes an Address object, possibly empty and invalid, and applies context-specific fixes... then returns it
          # this is just an irritating fix we needed for LCOR, no reason not to leave it in
          if addr.street_name == "Weaver St" && addr.street_number == "251" && addr.state == "CT"
            addr.zip_code = "06831"
          end
          return addr
        end
        
        def execute
          ######### DEFINE OUTPUT VARIABLES ###########

          to_return = {
            community_errors: {}, # [community prop id] = error string
            unit_errors: {},      # [community prop id][unit id] = error string
            unit_exclusions: {},  # [community prop id][unit id] = explanation string (errors are not present here, just exclusions)
            lease_errors: {},
            user_errors: {},
            promotion_errors: {},
            sync_results: []
          }
          output_array = []


          ##### BUILD communities ARRAY AND all_units HASH #########

          communities = Integrations::Yardi::RentersInsurance::GetPropertyConfigurations.run!({ integration: integration, property_id: property_list_id }.compact)
          communities = communities[:parsed_response].dig("Envelope", "Body", "GetPropertyConfigurationsResponse", "GetPropertyConfigurationsResult", "Properties", "Property")
          communities = [communities].compact unless communities.class == ::Array
          communities.select!{|comm| should_import_community(comm["Code"]) }
          all_units = {}
          communities.each do |comm|
            next unless should_import_community(comm["Code"])
            property_id = comm["Code"]
            units = nil
            begin
              units = Integrations::Yardi::RentersInsurance::GetUnitConfiguration.run!(integration: integration, property_id: property_id)
            rescue
              gortsnort = nil
              t = Time.current + 5.seconds
              while Time.current < t do
                gortsnort = 2
              end
              units = (Integrations::Yardi::RentersInsurance::GetUnitConfiguration.run!(integration: integration, property_id: property_id) rescue nil)
            end
            if units.nil?
              to_return[:community_errors][property_id] = "Attempt to retrieve unit list from Yardi failed."
              comm[:errored] = true
            else
              units = units[:parsed_response].dig("Envelope", "Body", "GetUnitConfigurationResponse", "GetUnitConfigurationResult", "Units", "Unit")
              units = [units].compact unless units.class == ::Array
              all_units[property_id] = units
              to_return[:unit_errors][property_id] = {}
              to_return[:unit_exclusions][property_id] = {}
            end
            addr_str = "#{comm["AddressLine1"]}, #{comm["City"]}, #{comm["State"]} #{comm["PostalCode"]}"
            addr = Address.from_string(addr_str)
            if addr.street_name.blank?
              to_return[:community_errors][property_id] = "Unable to parse community address (#{addr_str})"
              comm[:errored] = true
              all_units.delete(property_id)
            else
              addr = after_address_hacks(addr)
              comm[:gc_addr_obj] = addr
            end
          end
          
          if efficiency_mode && all_units.keys.count > 1
            all_units.keys.each do |k|
              Integrations::Yardi::Sync::Insurables.run!(integration: integration.reload, property_ids: [k], insurables_only: insurables_only, efficiency_mode: true)
            end
            return to_return # empty
          end
          
          ###### APPLY FORBIDDEN UNIT TYPES ######
          
          forbidden_unit_types = integration.configuration['sync']['forbidden_unit_types'] || []
          is_forbidden = if forbidden_unit_types.class == ::Array
            Proc.new{|u| forbidden_unit_types.include?(u["UnitType"]) }
          elsif forbidden_unit_types == "bmr"
            Proc.new{|u| u["UnitType"]&.downcase&.index("bmr") }
          elsif forbidden_unit_types == "nonconventional"
            Proc.new{|u| (u["Identification"].class == ::Array ? u["Identification"] : [u["Identification"]]).find{|i| i["IDType"] == "LeaseDesc" }&.[]("IDValue") != "Conventional" }
          else
            nil
          end
          unless forbidden_unit_types.blank?
            all_units = all_units.map do |k,v|
              uresult = ::Integrations::Yardi::ResidentData::GetUnitInformation.run!(integration: integration, property_id: k)
              unless uresult[:success]
                to_return[:community_errors][k] = "Could not import; failed to get Resident Data Unit Information to cull forbidden Unit Types"
                next [k, nil]
              end
              verboten = uresult[:parsed_response].dig("Envelope", "Body", "GetUnitInformationResponse", "GetUnitInformationResult", "UnitInformation", "Property", "Units", "UnitInfo")
                                                  .select{|u| is_forbidden.call(u["Unit"]) }
                                                  .map{|u| u["UnitID"]["__content__"] }
              ### format example:
              # <UnitInfo>
              #   <UnitID UniqueID="85223">506</UnitID>
              #   <PersonID Type="Current Resident">t0586444</PersonID>
              #   <Unit>
              #     <Identification IDType="LeaseDesc" IDValue="Conventional" />
              #     <Identification IDType="RentalType" IDValue="Residential" />
              #     <Identification IDType="UnitTypeUniqueID" IDValue="2331" />
              #     <UnitType>6712j</UnitType>
              #     <UnitBedrooms>1</UnitBedrooms>
              #     <UnitBathrooms>1.00</UnitBathrooms>
              #     <MinSquareFeet>750</MinSquareFeet>
              #     <MaxSquareFeet>750</MaxSquareFeet>
              #     <MarketRent>1705.00</MarketRent>
              #     <UnitEconomicStatus>residential</UnitEconomicStatus>
              #     <UnitEconomicStatusDescription>Occupied No Notice</UnitEconomicStatusDescription>
              #     <FloorplanName>1x1 740 - 760 SQFT - Aritosthenes</FloorplanName>
              #     <BuildingName />
              #     <Address AddressType="property">
              #       <AddressLine1>101 BIG MOOSE AVE APT 506</AddressLine1>
              #       <City>Little Rock</City>
              #       <State>AR</State>
              #       <PostalCode>72076</PostalCode>
              #     </Address>
              #   </Unit>
              # </UnitInfo>
              ###
              next [k,
                v.select do |u|
                  if verboten.include?(u["UnitId"])
                    to_return[:unit_exclusions][k][u["UnitId"]] = "Unit's UnitType is on blacklist"
                    next false
                  else
                    next true
                  end
                end
              ]
            end.to_h.compact
          end

          ###### CLEAN UP FAKE UNITS, FIX BROKEN ADDRESSES ##########

          all_units = all_units.map do |k,v|
            comm = communities.find{|c| c["Code"] == k }
            [k,
              v.map do |u|
                (to_return[:unit_exclusions][k][u["UnitId"]] = "Field 'Excluded' is not equal to 0."; next nil) if u["Excluded"] != "0" && u["Excluded"] != 0
                (to_return[:unit_exclusions][k][u["UnitId"]] = "Unit ID is #{u["UnitId"]}."; next nil) if ["NONRESID", "WAIT", "WAIT_AFF", "RETAIL"].include?(u["UnitId"])
                (to_return[:unit_exclusions][k][u["UnitId"]] = "Field 'Address' is blank."; next nil) if u["Address"].blank?
                addr = fixaddr(comm["MarketingName"], u["UnitId"], u["Address"])
                (to_return[:unit_errors][k][u["UnitId"]] = "Could not clean up address (Community name #{comm["MarketingName"]}, unit ID #{u["UnitId"]}, unit address #{u["Address"]})."; next nil) if addr.blank?
                u.merge({
                  gc_addr: addr
                })
              end.compact
            ]
          end.to_h

          ###### CHECK FOR ADDRESS VALIDITY #####

          all_units = all_units.map do |k,v|
            [k,
              v.map do |u|
                addr = Address.from_string("#{u[:gc_addr]}, #{u["City"]}, #{u["State"]} #{u["PostalCode"]}")
                if addr.street_name.blank?
                  to_return[:unit_errors][k][u["UnitId"]] = "Unable to parse address (#{u[:gc_addr]}, #{u["City"]}, #{u["State"]} #{u["PostalCode"]})"
                  nil
                else
                  addr = after_address_hacks(addr)
                  u[:gc_addr_obj] = addr
                  u
                end
              end.compact
            ]
          end.to_h


          ###### CHECK FOR UNIT NUMBERS #######  
            
          all_units = all_units.map do |k,v|
            [k,
              v.map do |u|
                next u unless u[:gc_addr_obj].street_two.blank?
                if v.select{|uu| uu[:gc_addr_obj].street_name == u[:gc_addr_obj].street_name && uu[:gc_addr_obj].street_number == u[:gc_addr_obj].street_number }.size > 1
                  u[:gc_addr_obj].street_two = u["UnitId"]
                  next u
                end
                next u if u["UnitId"] == u[:gc_addr_obj].street_number || u["UnitId"] == "#{u[:gc_addr_obj].street_number}-0" || u["UnitId"].chomp(u[:gc_addr_obj].street_number).chars.all?{|c| c == "0" || c == " " || c == "-" }
                to_return[:unit_errors][k][u["UnitId"]] = "Unable to determine line two of address, but UnitId does not seem to conform to line one (UnitId '#{u["UnitId"]}', address '#{u["Address"]}', parsed as '#{u[:gc_addr_obj].full}')"
                next nil
              end.compact
            ]
          end.to_h


          ###### CULL COMMUNITIES WHOSE UNITS HAVE ALL FAILED ######

          all_units.select! do |k,v|
            if v.blank?
              to_return[:community_errors][k] = "No units in this community were importable."
              next false
            end
            next true
          end


          ###### DIVIDE INTO BUILDINGS #######

          by_building = all_units.transform_values do |units|
            units.group_by{|u| [u[:gc_addr_obj].street_name, u[:gc_addr_obj].street_number, u[:gc_addr_obj].city, u[:gc_addr_obj].state, u[:gc_addr_obj].zip_code] }
          end


          ###### MAKE HASH #########

          output_array = communities.select{|comm| !comm[:errored] }.map do |comm|
            {
              yardi_id: comm["Code"],
              title: comm["MarketingName"],
              address: "#{comm["AddressLine1"]}, #{comm["City"]}, #{comm["State"]} #{comm["PostalCode"]}",
            }.merge({
                buildings: (by_building[comm["Code"]] || {}).map do |bldg, units|
                  {
                    is_community: ("#{bldg[1]} #{bldg[0]}" == comm[:gc_addr_obj].combined_street_address && bldg[2] == comm[:gc_addr_obj].city && bldg[3] == comm[:gc_addr_obj].state && bldg[4] == comm[:gc_addr_obj].zip_code),
                    street_name: bldg[0],
                    street_number: bldg[1],
                    city: bldg[2],
                    state: bldg[3],
                    zip_code: bldg[4],
                    units: units.map do |unit|
                      {
                        title: unit[:gc_addr_obj].street_two,
                        yardi_id: unit["UnitId"],
                        yardi_data: unit
                      }
                    end
                  }
                end
              }
            )
          end


          ###### HANDLE COMMUNITIES ######

          community_ips = IntegrationProfile.where(integration: integration, profileable_type: "Insurable", external_context: "community").to_a
          local_unmatched_ips = community_ips.select{|ip| !output_array.any?{|comm| comm[:yardi_id] == ip.external_id } && !to_return[:community_errors].has_key?(ip.external_id) }
          output_array.each do |comm|
            next if comm[:errored]
            errored = false
            ip = community_ips.find{|ip| ip.external_id == comm[:yardi_id] }
            if ip.nil?
              # look for previous IP that matches it
              ip = local_unmatched_ips.find do |ip|
                addr = ip.profileable.primary_address
                caddr = comm[:gc_addr_obj]
#puts "!!!!!!!!!!!!! The comm is:"
#puts comm
#puts "!!!!!!!!!!!!! The unmatched IP is:"
#puts "#{ip.to_json}"
#puts "!!!!!!!!!!!!! and addr is #{addr ? "not null" : "null"}"
#puts "!!!!!!!!!!!!! and caddr is #{caddr ? "not null" : "null"}"
                next if caddr.nil?
                next "#{addr.combined_street_address}, #{addr.city}, #{addr.state} #{addr.zip_code}" == "#{caddr.combined_street_address}, #{caddr.city}, #{caddr.state} #{caddr.zip_code}"
              end
              if !ip.nil?
                # we found a match... they've changed the id -_-
                ip.update(external_id: comm[:yardi_id])
                IntegrationProfile.where(integration: integration, profileable_type: "Insurable", profileable_id: ip.profileable.units.map{|u| u.id }).update_all(external_context: "unit_in_community_#{comm[:yardi_id]}")
                # MOOSE WARNING: need to change anything else?
              else
                # look for/create a matching community
                community = ::Insurable.get_or_create(
                  address: comm[:address],
                  unit: false,
                  disallow_creation: false,
                  create_if_ambiguous: true,
                  created_community_title: comm[:title],
                  communities_only: true,
                  account_id: account_id
                )
                case community
                  when ::Insurable
                    # do nothing, community is already set correctly
                  when ::Array
                    found = community.select{|c| c.account_id == account_id }
                    found.select!{|c| c.title == comm[:title] } unless found.count <= 1 || comm[:title].blank?
                    unless found.count == 1
                      comm[:errored] = true
                      to_return[:community_errors][comm[:yardi_id]] = "Community address was ambiguous; community address '#{comm[:address]}', get-or-create returned multiple results (ids: #{community.map{|c| c.id }})"
                    end
                    community = found.first
                  when ::Hash
                    comm[:errored] = true
                    to_return[:community_errors][comm[:yardi_id]] = "Community address failure; community address '#{comm[:address]}', get-or-create returned #{community.to_s}"
                  when ::NilClass
                    comm[:errored] = true
                    to_return[:community_errors][comm[:yardi_id]] = "Community address failure; community address '#{comm[:address]}', get-or-create returned nil"
                end
                if community.class == ::Insurable && !community.account_id.nil? && community.account_id != account_id
                  comm[:errored] = true
                  to_return[:community_errors][comm[:yardi_id]] = "Community is registered to another account (community id ##{community.id}, account id ##{account_id})"
                end
                next if comm[:errored]
                # fix matching community fields if necessary
                community.update(title: comm[:title], account_id: account_id, confirmed: true) if community.account_id != account_id && !community.confirmed
                community.qbe_mark_preferred unless community.preferred_ho4
                # create the ip
                ip = IntegrationProfile.create(
                  integration: integration,
                  profileable: community,
                  external_context: "community",
                  external_id: comm[:yardi_id],
                  configuration: {
                    'synced_at' => Time.current.to_s
                  }
                )
                if ip.id.nil?
                  comm[:errored] = true
                  to_return[:community_errors][comm[:yardi_id]] = "Encountered an error while saving IntegrationProfile: #{ip.errors.to_h}"
                  next
                end
              end
            end
            # last line of defense against missing IP
            if ip.nil?
              comm[:errored] = true
              to_return[:community_errors][comm[:yardi_id]] = "Unknown error occurred; unable to find/create IntegrationProfile"
              next
            end
            # log the stuff bro
            comm[:integration_profile] = ip
            comm[:insurable] = ip.profileable
          end
          output_array.select!{|comm| !comm[:errored] }


          ###### HANDLE UNITS ######

          output_array.each do |comm|
            comm[:buildings].each do |bldg|
              addr = ::Address.new(street_name: bldg[:street_name], street_number: bldg[:street_number], city: bldg[:city], state: bldg[:state], zip_code: bldg[:zip_code])
              addr.standardize_case; addr.set_full; addr.set_full_searchable; addr.from_full; addr.standardize
              building = (comm[:buildings].length == 1 && bldg[:is_community] ? comm[:insurable] : comm[:insurable].buildings.confirmed.find{|b| b.primary_address.street_name == addr.street_name && b.primary_address.street_number == addr.street_number })
              if building.nil?
                building = Insurable.create(
                  insurable_id: comm[:insurable].id,
                  title: "#{bldg[:street_number]} #{bldg[:street_name]}",
                  insurable_type_id: 7,
                  enabled: true, preferred_ho4: false, category: 'property',
                  addresses: [ addr ],
                  account_id: account_id, confirmed: true
                )
                if building.id.nil?
                  bldg[:units].each do |u|
                    to_return[:unit_errors][comm[:yardi_id]][u[:yardi_id]] = "Failed to create building; got error #{building.errors.to_h}."
                  end
                  bldg[:errored] = true
                  next
                end
              end
              # ensure building is properly set up
              if building.account_id != account_id && building.insurable_type_id == 7
                if building.account_id.nil?
                  building.update(account_id: account_id, confirmed: true)
                else
                  bldg[:units].each do |u|
                    to_return[:unit_errors][comm[:yardi_id]][u[:yardi_id]] = "Building already exists and belongs to the wrong account (insurable #{building.id} has account_id #{building.account_id} instead of #{account_id})."
                  end
                  bldg[:errored] = true
                  next
                end
              elsif !building.confirmed
                building.update(confirmed: true)
              end
              # building is now the building/community insurable we should create units for
              bldg[:insurable] = building # NOTE: does not have an IntegrationProfile
              ips = IntegrationProfile.where(integration: integration, profileable_type: "Insurable", external_context: "unit_in_community_#{comm[:yardi_id]}")
              bldg[:units].each do |u|
                # try to find ip
                found_ip = ips.find{|ip| ip.external_id == u[:yardi_id] }
                if found_ip
                  u[:integration_profile] = found_ip
                  u[:insurable] = found_ip.profileable
                  next
                end
                # try to find unit
                unit = building.units.find{|uu| uu.title == u[:title] }
                # try to bring the existing unit into the system
                if !unit.nil?
                  if unit.account_id != account_id && !unit.account_id.nil?
                    u[:errored] = true
                    to_return[:unit_errors][comm[:yardi_id]][u[:yardi_id]] = "Unit already exists and belongs to the wrong account (insurable #{unit.id} has account_id #{unit.account_id} instead of #{account_id})."
                    next
                  end
                end
                # create the unit
                if unit.nil?
                  unit = ::Insurable.create(
                    insurable_id: building.id,
                    title: u[:title],
                    insurable_type_id: 4,
                    enabled: true, preferred_ho4: false, category: 'property',
                    account_id: account_id, confirmed: true
                  )
                  if unit.id.nil?
                    u[:errored] = true
                    to_return[:unit_errors][comm[:yardi_id]][u[:yardi_id]] = "Failed to create unit; got error #{unit.errors.to_h}."
                    next
                  end
                end
                # create the IntegrationProfile
                ip = IntegrationProfile.create(
                  integration: integration,
                  profileable: unit,
                  external_context: "unit_in_community_#{comm[:yardi_id]}",
                  external_id: u[:yardi_id],
                  configuration: {
                    'synced_at' => Time.current.to_s
                  }
                )
                if ip.id.nil?
                  u[:errored] = true
                  to_return[:unit_errors][comm[:yardi_id]][u[:yardi_id]] = "Encountered an error while saving IntegrationProfile: #{ip.errors.to_h}"
                  next
                end
                # log the created unit
                u[:insurable] = unit
                u[:integration_profile] = ip
              end # end unit loop
              bldg[:units].select!{|u| !u[:errored] }
              # kill if empty
              if building.reload.insurables.reload.blank?
                building.addresses.delete_all
                building.delete
              end
            end # end building loop
            comm[:buildings].select!{|b| !b[:errored] }
          end # end community loop
          
          
          ###### TENANT IMPORT ######
   
          tenant_array = []
          unless insurables_only
            output_array.each do |comm|
              result = Integrations::Yardi::Sync::Roommates.run!(integration: integration, property_id: comm[:yardi_id])
              comm[:last_sync_f] = result[:last_sync_f]
              to_return[:promotion_errors][comm[:yardi_id]] = result[:errors] unless result[:errors].blank?
              comm[:buildings].each do |bldg|
                bldg[:units].each do |unit|
                  next if unit[:yardi_data]["Resident"].blank?
                  result = Integrations::Yardi::Sync::Leases.run!(integration: integration, update_old: true, unit: unit[:insurable], resident_data: unit[:yardi_data]["Resident"].class == ::Array ? unit[:yardi_data]["Resident"] : [unit[:yardi_data]["Resident"]])
                  unless result[:lease_errors].blank?
                    to_return[:lease_errors][comm[:yardi_id]] ||= {}
                    to_return[:lease_errors][comm[:yardi_id]][unit[:yardi_id]] = result[:lease_errors]
                  end
                  unless result[:user_errors].blank?
                    to_return[:user_errors][comm[:yardi_id]] ||= {}
                    to_return[:user_errors][comm[:yardi_id]][unit[:yardi_id]] = result[:user_errors]
                  end
                  [:leases_created, :leases_found, :leases_expired, :users_created, :users_found].each do |prop|
                    unit[prop] = result[prop]
                  end
                end
              end
            end
          end
          
          ###### UPDATE syncable_communities LIST ######
          
          integration.configuration['sync'] ||= {}
          integration.configuration['sync']['syncable_communities'] ||= {}
          output_array.each do |comm|
            integration.configuration['sync']['syncable_communities'][comm[:yardi_id]] ||= {}
            integration.configuration['sync']['syncable_communities'][comm[:yardi_id]]["name"] = comm[:title]
            integration.configuration['sync']['syncable_communities'][comm[:yardi_id]]["gc_id"] = comm[:insurable]&.id
            integration.configuration['sync']['syncable_communities'][comm[:yardi_id]]["last_sync_f"] = comm[:last_sync_f]
            integration.configuration['sync']['syncable_communities'][comm[:yardi_id]]["last_sync_i"] = Time.current.to_date.to_s
          end
          integration.configuration['sync']['sync_history'] ||= []
          integration.configuration['sync']['sync_history'].push({
            'log_format' => '1.0',
            'event_type' => "sync_insurables",
            'message' => "Synced properties, users, and leases.",
            'timestamp' => Time.current.to_s,
            'errors' => to_return.select{|k,v| k != :sync_results }
          })
          integration.save
          
          ###### ORGANIZE & RETURN RESULTS ######
          
          to_return[:unit_errors].select!{|k,v| !v.blank? }
          to_return[:unit_exclusions].select!{|k,v| !v.blank? }
          to_return[:sync_results] = output_array unless efficiency_mode
          return to_return

        end # end execute
      end # end class Insurables
    end # end module Sync
  end # end module Yardi
end # end module Integrations















