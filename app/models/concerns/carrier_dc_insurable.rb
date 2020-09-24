##
# =Direct Current--*cough cough excuse me* DepositChoice--Insurable Functions Concern
# file: +app/models/concerns/carrier_dc_insurable.rb+

module CarrierDcInsurable
  extend ActiveSupport::Concern
  
  included do
    
    # should only be called on units; will fail on communities
    def dc_get_rates(effective_date)
      unit_profile = self.carrier_profile(DepositChoiceService.carrier_id)
      # get rates
      dcs = DepositChoiceService.new
      dcs.build_request(:rate, { 
        unit_id: unit_profile.external_carrier_id,
        effective_date: effective_date
      }.compact)
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
      dcs.build_request(:address, { 
        address1: address1,
        address2: address2,
        city: city,
        state: state,
        zip_code: zip_code
      }.compact)
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
      # w00t w00t
      return result[:data]
    end
    
    ########## THIS IS ALL HIDEOUSLY BROKEN. UGH! #################
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
