##
# =Direct Current--*cough cough excuse me* DepositChoice--Insurable Functions Concern
# file: +app/models/concerns/carrier_dc_insurable.rb+

module CarrierDcInsurable
  extend ActiveSupport::Concern
  
  included do
    
    # should only be called on communities... MOOSE WARNING: do we need to add extra logic for buildings with their own addresses?
    def obtain_dc_information
      @carrier_id = DepositChoiceService.carrier_id
      @carrier_profile = carrier_profile(@carrier_id)
      return ["Unable to load carrier profile"] if @carrier_profile.nil?
      # try to get info from dc
      pad = self.primary_address
      return ["Insurable has no primary address"] if pad.nil?
      result = self.class.deposit_choice_address_search(
        address1: pad.combined_street_address,
        address2: pad.street_two.blank? ? nil : pad.street_two,
        city: pad.city,
        state: pad.state,
        zip_code: pad.zip_code
      )
      # check for errors
      if result[:error]
        @carrier_profile.update(profile_data: @carrier_profile.profile_data.merge({
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
        profile_data: @carrier_profile.profile_data.merge({
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
      entry_unit_ids_used = []
      self.units.each do |unit|
        cip = unit.carrier_profile(@carrier_id)
        if cip.nil?
          units_ignored_for_lack_of_cip.push(unit.id)
        else
          entry = result[:data]["units"].find{|ue| ue["unitValue"].strip == unit.title.strip }
          if entry.nil?
            units_not_in_dc_system.push(unit.id)
            cip.update(
              external_carrier_id: nil,
              profile_data: cip.profile_data.merge({
                "got_dc_information" => false,
                "dc_address_id" => result[:data]["addressId"],
                "dc_community_id" => nil,
                "dc_unit_id" => nil
              })
            )
          else
            entry_unit_ids_used.push(entry["unitId"])
            cip.update(
              external_carrier_id: entry["unitId"],
              profile_data: cip.profile_data.merge({
                "got_dc_information" => true,
                "dc_address_id" => result[:data]["addressId"],
                "dc_community_id" => entry["communityId"],
                "dc_unit_id" => entry["unitId"]
              })
            )
          end
        end
      end
      # save any missing unit info
      @carrier_profile.update(
        profile_data: @carrier_profile.profile_data.merge({
          "dc_units_not_in_system" => result[:data]["units"].select{|u| !entry_unit_ids_used.include?(u["unitId"]) }.map{|u| u["unitId"] },
          "units_not_in_dc_system" => units_not_in_dc_system,
          "units_ignored_for_lack_of_cip" => units_ignored_for_lack_of_cip
        })
      )
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
      event = events.new(
        verb: DepositChoiceService::HTTP_VERB_DICTIONARY[:rate].to_s,
        format: 'json',
        interface: 'REST',
        endpoint: dcs.endpoint_for(:rate),
        process: 'deposit_choice_rate'
      )
      event.request = dcs.message_content
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:data]
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
    
    def deposit_choice_address_search(address1:, address2: nil, city:, state:, zip_code:)
      # make the address call
      dcs = DepositChoiceService.new
      dcs.build_request(:address, 
        address1: address1,
        address2: address2,
        city: city,
        state: state,
        zip_code: zip_code
      )
      event = events.new(
        verb: DepositChoiceService::HTTP_VERB_DICTIONARY[:address].to_s,
        format: 'json',
        interface: 'REST',
        endpoint: dcs.endpoint_for(:address),
        process: 'deposit_choice_address'
      )
      event.request = dcs.message_content
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:data]
      event.status = result[:error] ? 'error' : 'success'
      event.save
      result[:event] = event
      # w00t w00t
      return result
    end
    
    ########## THIS IS ALL HIDEOUSLY BROKEN. UGH! BUT WE MAY NEVER NEED IT... HERE JUST IN CASE. #################
    def deposit_choice_get_insurable_from_response(response, unit_id: nil
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
    
    
  end
  
end
