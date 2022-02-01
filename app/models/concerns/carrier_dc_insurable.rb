##
# =Direct Current--*cough cough excuse me* DepositChoice--Insurable Functions Concern
# file: +app/models/concerns/carrier_dc_insurable.rb+

module CarrierDcInsurable
  extend ActiveSupport::Concern
  
  included do
    
    # should only be called on communities
    def obtain_dc_information(query_result_override: nil)
      @carrier_id = DepositChoiceService.carrier_id
      @carrier_profile = carrier_profile(@carrier_id) || self.create_carrier_profile(@carrier_id)
      return ["Unable to load carrier profile"] if @carrier_profile.nil?
      # try to get info from dc
      pad = self.primary_address
      return ["Insurable has no primary address"] if pad.nil?
      result = query_result_override || self.class.deposit_choice_address_search(
        address1: pad.combined_street_address,
        address2: pad.street_two.blank? ? nil : pad.street_two,
        city: pad.city,
        state: pad.state,
        zip_code: pad.zip_code,
        eventable: self
      )
      # check for errors
      if result[:error]
        @carrier_profile.update(data: @carrier_profile.data.merge({
          "sought_dc_information" => true,
          "sought_dc_information_on" => Time.current.to_date.to_s,
          "got_dc_information" => false,
          "dc_information_event_id" => result[:event]&.id
        }))
        return ["DepositChoice address search returned an error"]
      end
      # mark success
      @carrier_profile.update(
        external_carrier_id: result[:data]["addressId"],
        data: @carrier_profile.data.merge({
          "sought_dc_information" => true,
          "sought_dc_information_on" => Time.current.to_date.to_s,
          "got_dc_information" => true,
          "dc_information_event_id" => result[:event]&.id,
          "dc_address_id" => result[:data]["addressId"]
        })
      )
      # fill out unit info
      units_ignored_for_lack_of_cip = []
      dc_units_not_in_system = []
      units_not_in_dc_system = []
      units_entered = []
      entry_unit_ids_used = []
      unit_dc_ids = result[:data]["units"].map{|u| u["unitId"] }
      self.units.confirmed.each do |unit|
        cip = unit.carrier_profile(@carrier_id) || unit.create_carrier_profile(@carrier_id)
        if cip.nil?
          units_ignored_for_lack_of_cip.push(unit.id)
        else
          entry = result[:data]["units"].find{|ue| ue["unitValue"].strip == (unit.title&.strip || pad.street_number.strip) }
          if entry.nil?
            units_not_in_dc_system.push(unit.id)
            cip.update(
              external_carrier_id: nil,
              data: cip.data.merge({
                "got_dc_information" => false,
                "dc_address_id" => nil,
                "dc_community_id" => nil,
                "dc_unit_id" => nil
              })
            )
          else
            units_entered.push(unit.id)
            entry_unit_ids_used.push(entry["unitId"])
            cip.update(
              external_carrier_id: entry["unitId"],
              data: cip.data.merge({
                "got_dc_information" => true,
                "dc_address_id" => result[:data]["addressId"],
                "dc_community_id" => entry["communityId"],
                "dc_unit_id" => entry["unitId"]
              })
            )
            unit.update(policy_type_ids: ((unit.policy_type_ids || []) + [::DepositChoiceService.policy_type_id]).uniq)
          end
        end
      end
      # try to use buildings to fill out more unit info
      building_address_ids = {}
      buildings = insurables.where(insurable_type_id: 7).confirmed
      buildings.each do |building|
        # try to get info from dc using building addresses
        pad = building.primary_address
        next if pad.nil?
        result = self.class.deposit_choice_address_search(
          address1: pad.combined_street_address,
          address2: pad.street_two.blank? ? nil : pad.street_two,
          city: pad.city,
          state: pad.state,
          zip_code: pad.zip_code,
          eventable: building
        )
        if result[:error]
          next
        end
        building_address_ids[building.id] = result[:data]["addressId"]
        unit_dc_ids.concat(result[:data]["units"].map{|u| u["unitId"] })
        # grab extra unit info
        building.units.confirmed.each do |unit|
          cip = unit.carrier_profile(@carrier_id) || unit.create_carrier_profile(@carrier_id)
          if cip.nil?
            units_ignored_for_lack_of_cip.push(unit.id)
          else
            entry = result[:data]["units"].find{|ue| ue["unitValue"].strip == (unit.title&.strip || pad.street_number.strip) }
            if entry.nil?
              units_not_in_dc_system.push(unit.id)
              cip.update(
                external_carrier_id: nil,
                data: cip.data.merge({
                  "got_dc_information" => false,
                  "dc_address_id" => nil,
                  "dc_community_id" => nil,
                  "dc_unit_id" => nil
                })
              )
            else
              units_entered.push(unit.id)
              entry_unit_ids_used.push(entry["unitId"])
              cip.update(
                external_carrier_id: entry["unitId"],
                data: cip.data.merge({
                  "got_dc_information" => true,
                  "dc_address_id" => result[:data]["addressId"],
                  "dc_community_id" => entry["communityId"],
                  "dc_unit_id" => entry["unitId"]
                })
              )
              unit.update(policy_type_ids: ((unit.policy_type_ids || []) + [::DepositChoiceService.policy_type_id]).uniq)
            end
          end
        end
      end
      # save log of relevant info
      @carrier_profile.update(
        data: @carrier_profile.data.merge({
          "building_address_ids" => building_address_ids,
          "dc_units_not_in_system" => unit_dc_ids.uniq.select{|u| !entry_unit_ids_used.include?(u) },
          "units_not_in_dc_system" => units_not_in_dc_system.uniq,
          "units_ignored_for_lack_of_cip" => units_ignored_for_lack_of_cip.uniq,
          "units_matched" => units_entered
        })
      )
      self.update(policy_type_ids: ((self.policy_type_ids || []) + [::DepositChoiceService.policy_type_id]).uniq) unless units_entered.blank?
      # return success
      return nil
    end
    
    # should only be called on units; will fail on communities
    def dc_get_rates(effective_date)
      unit_profile = self.carrier_profile(DepositChoiceService.carrier_id)
      # get rates
      dcs = DepositChoiceService.new
      dcs.build_request(:rate, 
        unit_id: unit_profile.external_carrier_id,
        effective_date: effective_date
      )
      event = self.events.new(dcs.event_params)
      event.request = dcs.message_content
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:response].response.body
      event.request = result[:response].request.raw_body
      event.endpoint = result[:response].request.uri.to_s
      event.status = result[:error] ? 'error' : 'success'
      event.save
      # make sure we succeeded
      if result[:error]
        return { success: false, error: "Deposit Choice rate retrieval unsuccessful", event: event }
      elsif result[:data]&.[]("rates").nil?
        return { success: false, error: "Deposit Choice rate retrieval failed", event: event }
      end
      # grab dem rates
      return { success: true, rates: result[:data]["rates"].map{|r| r.transform_values{|v| (v.gsub(/[^\d.]/, '').to_d * 100).ceil } }, event: event }
      # rates is an array of hashes of the form:
      #{
      #  "bondAmount": 100000, #i.e. $1000.00
      #  "ratedPremium": 17500,
      #  "processingFee": 569,
      #  "totalCost": 18069
      #}
    end
    
    
  end
  
  class_methods do
    
    def deposit_choice_address_search(address1:, address2: nil, city:, state:, zip_code:, eventable: nil)
      # make the address call
      dcs = DepositChoiceService.new
      dcs.build_request(:address, 
        address1: address1,
        address2: address2,
        city: city,
        state: state,
        zip_code: zip_code
      )
      event = Event.new(dcs.event_params)
      event.eventable = eventable
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:response].response.body
      event.request = result[:response].request.raw_body
      event.endpoint = result[:response].request.uri.to_s
      event.status = result[:error] ? 'error' : 'success'
      event.save
      result[:event] = event
      # w00t w00t
      return result
    end
    
    ########## THIS IS HIDEOUSLY BROKEN. UGH! BUT WE MAY NEVER NEED IT... HERE JUST IN CASE. #################
    def deposit_choice_get_insurable_from_response(response, 
      unit_id: nil,
      allow_insurable_creation: true
    )
      # search for an insurable with the right id
      community = ::CarrierInsurableProfile.where(carrier_id: DepositChoiceService.carrier_id, external_carrier_id: response["addressId"]).take
      if community.nil?
        # grab address pieces
        line1 = ::Address.separate_street_number(response["address1"])
        line2 = response["address2"]
        city = response["city"]
        state = response["stateCode"]
        zip_code = response["zipCode"]
        if line1 == false
          puts "Error: Deposit Choice response has invalid address '#{response["address1"]}'; unable to separate street number!"
          return nil # MOOSE WARNING: better error return...?
        end
        # search for address
        found = Address.where(street_number: line1[0], street_name: line1[1], street_two: line2, city: city, state: state, zip_code: zip_code, addressable_type: insurable).take
        if !found.nil?
          found = found.addressable.parent_community || found.addressable
        else
          unless allow_insurable_creation
            puts "Error: Deposit Choice response references a community not present in the database, and insurable creation is forbidden"
            return nil # MOOSE WARNING: better error return...?
          end
          # create insurable
        end
        # add external id to address
      end
    end
    
    # only creates communities with no buildings for now
    # - result should be the return value from deposit_choice_address_search
    def deposit_choice_create_insurable_from_response(result,
      account: nil, account_id: account&.id || nil,
      agency: nil, agency_id: agency&.id || nil,
      destroy_on_dc_information_failure: true
    )
      return { "Community address" => ["rejected by Deposit Choice"] } if result[:error]
      response = result[:data]
      # validate input
      if !account_id.nil? && !agency_id.nil?
        account ||= Account.where(id: account_id).take
        return { "Provided account" => ["is nonexistent"] } if account.nil?
        return { "Provided account and agency" => ["are not associated"] } if account.agency_id != agency_id
      end
      blanks = ["addressId", "address1", "city", "stateCode", "zipCode", "units"].select{|p| response[p].blank? }
      return { "Deposit Choice community data" => ["is missing required field#{blanks.count == 1 ? "" : "s"}: #{blanks.map{|b| "'#{b}'"}.join(", ")}"] } unless blanks.blank?
      if response["units"].map{|u| u["communityId"].strip }.uniq.count > 1
        return { "Deposit Choice community data" => ["indicates address corresponds to multiple communities"] }
      end
      # create stuff
      return_errors = nil
      community = nil
      ActiveRecord::Base.transaction do
        # create community
        street_number = response["address1"].split(" ")[0]
        street_name = response["address1"].split(" ").drop(1).join(" ")
        community = Insurable.new({
          account_id: account_id,
          agency_id: agency_id,
          title: response["units"].first["communityName"], # MOOSE WARNING: this may be a garbage name... trusting the DC data to be correct here could be dangerous
          insurable_type: InsurableType.where(title: "Residential Community").take,
          enabled: true,
          category: 'property',
          addresses_attributes: [{
            street_number: street_number,
            street_name: street_name,
            city: response["city"],
            state: response["stateCode"],
            zip_code: response["zipCode"]
          }]
        }.compact)
        unless community.save
          return_errors = community.errors.to_h.transform_keys{|k| "Community #{k.to_s}" }
          raise ActiveRecord::Rollback
        end
        begin
          community.create_carrier_profile(DepositChoiceService.carrier_id)
          community.update(policy_type_ids: ((community.policy_type_ids || []) + [::DepositChoiceService.policy_type_id]).uniq)
        rescue ActiveRecord::RecordInvalid => e
          return_errors =  e.record.errors.to_h.transform_keys{|k| "Community Profile #{k.to_s}" }
          raise ActiveRecord::Rollback
        end
        # create units
        if response["units"].blank?
          return_errors = "Response from Deposit Choice specified a community with no units"
          raise ActiveRecord::Rollback
        end
        unit_insurable_type = InsurableType.where(title: "Residential Unit").take
        response["units"].each do |unit_entry|
          unit = community.insurables.new({
            title: unit_entry["unitValue"],
            insurable_type: unit_insurable_type,
            enabled: true,
            category: 'property',
            account_id: account_id,
            agency_id: agency_id
          }.compact)
          unless unit.save
            return_errors = unit.errors.to_h.transform_keys{|k| "Unit #{unit_entry["unitValue"]} #{k.to_s}" }
            raise ActiveRecord::Rollback
          end
          begin
            unit.create_carrier_profile(DepositChoiceService.carrier_id)
            unit.update(policy_type_ids: ((unit.policy_type_ids || []) + [::DepositChoiceService.policy_type_id]).uniq)
          rescue ActiveRecord::RecordInvalid => e
            return_errors =  e.record.errors.to_h.transform_keys{|k| "Unit #{unit_entry["unitValue"]} Profile #{k.to_s}" }
            raise ActiveRecord::Rollback
          end
        end
        # do the magic, bro
        odci_errors = community.obtain_dc_information(query_result_override: result)
        if !odci_errors.blank? && destroy_on_dc_information_failure
          return_errors = {"Deposit Choice Query Failure" => odci_errors}
          raise ActiveRecord::Rollback
        end
      end
      # handle errors or return community
      if !return_errors.blank?
        return return_errors
      end
      return community
    end
    
    
  end # end class_methods
  
end
