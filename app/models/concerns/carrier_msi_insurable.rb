##
# =MSI Insurable Functions Concern
# file: +app/models/concerns/carrier_msi_insurable.rb+

module CarrierMsiInsurable
  extend ActiveSupport::Concern

  included do
  
    def msi_carrier_id
      5
    end
    
    def msi_get_carrier_status(refresh: false)
      @msi_get_carrier_status = nil if refresh
      return @msi_get_carrier_status ||= !::InsurableType::RESIDENTIAL_IDS.include?(self.insurable_type_id) ?
        nil
        : (self.confirmed && self.parent_community&.carrier_profile(::MsiService.carrier_id)&.external_carrier_id ? :preferred : :nonpreferred)
    end
	  
    def register_with_msi
      # load the stuff we need
      return ["Insurable must be a residential community"] if self.insurable_type.title != "Residential Community"
      return ["Insurable must be confirmed"] if !self.confirmed
	    @carrier = Carrier.where(id: msi_carrier_id).take
      return ["Unable to load carrier information"] if @carrier.nil?
	    @carrier_profile = carrier_profile(@carrier.id)
      self.create_carrier_profile(@carrier.id) if @carrier_profile.nil?
	    @address = primary_address()
	    return ["Community lacks a primary address"] if @address.nil?
      # try to build the request
      msis = MsiService.new
      succeeded = msis.build_request(:get_or_create_community,
        community_name:                 self.title,
        number_of_units:                residential_units.confirmed.count,
        property_manager_name:          account&.title,
        years_professionally_managed:   (@carrier_profile.traits['professionally_managed'] != false) ?
                                          (@carrier_profile.traits['professionally_managed_year'].nil? ?
                                            6 :
                                            Time.current.year + 1 - @carrier_profile.traits['professionally_managed_year'].to_i # +1 so that we round up instead of down
                                          ) :
                                          0,
        year_built:                     @carrier_profile.traits['construction_year'],
        gated:                          @carrier_profile.traits['gated'],
        
        address_line_one:               @address.combined_street_address,
        city:                           @address.city,
        state:                          @address.state,
        zip:                            @address.zip_code
      )
      if !succeeded
        if msis.errors.blank?
          return ["Building GetOrCreateCommunity request failed"]
        else
          return msis.errors.map{|err| "GetOrCreateCommunity service call error: #{err}" }
        end
      end
      event = events.new(msis.event_params)
      event.request = msis.compiled_rxml
      # try to execute the request
      if !event.save
        return ["Failed to save service call status-tracking Event: #{event.errors.to_h}"]
      else
        # execute & log
        event.started = Time.now
        msi_data = msis.call
        event.completed = Time.now
        event.response = msi_data[:response].response.body
        event.status = msi_data[:error] ? 'error' : 'success'
        unless event.save
          return ["Failed to save response to service call status-tracking Event"]
        end
        # handle response
        if msi_data[:error]
          return ["Service call resulted in error"]
        else
          # grab the id
          external_id = msi_data[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "MSI_CommunityInfo", "MSI_CommunityID")
          if external_id.nil?
            return ["Successful service call did not return an id"]
          end
          @carrier_profile.update_columns(external_carrier_id: external_id)
          # handle address corrections
          address_data = msi_data[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "MSI_CommunityInfo", "Addr")
          if address_data&.dig("DetailAddr", "MSI_AddressScrubSuccessful")
            @carrier_profile.data['address_correction_data'] = {}
            # collect address fixes... WARNING: probably city and state, and possibly the rest (except county and plus four), shouldn't be fixable here...? depends on what fields we trust MSI to "fix"
            if !address_data["StateProvCd"].blank? && address_data["StateProvCd"].strip.upcase != @address.state
              @carrier_profile.data['address_correction_data']['state'] = { 'from' => @address.state, 'to' => address_data["StateProvCd"].strip.upcase }
            end
            if !address_data["City"].blank? && address_data["City"].downcase.gsub(/[^0-9a-z]/i, '') != @address.city&.downcase&.gsub(/[^0-9a-z]/i, '')
              @carrier_profile.data['address_correction_data']['city'] = { 'from' => @address.city, 'to' => address_data["City"] }
            end
            if !address_data["County"].blank? && address_data["County"].strip.upcase != @address.county&.strip&.upcase
              @carrier_profile.data['address_correction_data']['county'] = { 'from' => @address.county, 'to' => address_data["County"].strip.upcase }
            end
            if !address_data["PostalCode"].blank? && address_data["PostalCode"].gsub(/[^0-9]/i, '')[0..4] != @address.zip_code
              @carrier_profile.data['address_correction_data']['zip_code'] = { 'from' => @address.zip_code, 'to' => address_data["PostalCode"].gsub(/[^0-9]/i, '')[0..4] }
            end
            if !address_data["PostalCode4"].blank? && address_data["PostalCode4"].gsub(/[^0-9]/i, '')[0..3] != @address.plus_four
              @carrier_profile.data['address_correction_data']['plus_four'] = { 'from' => @address.plus_four, 'to' => address_data["PostalCode4"].gsub(/[^0-9]/i, '')[0..3] }
            end
            # fix address
            if @carrier_profile.data['address_correction_data'].blank?
              @carrier_profile.data['address_corrected'] = false
            else
              @carrier_profile.data['address_corrected'] = true
              unless @address.update(@carrier_profile.data['address_correction_data'].map{|prop,change| [prop.to_s, change['to']] }.to_h)
                @carrier_profile.data['address_correction_failed'] = true
                @carrier_profile.data['address_correction_errors'] = @address.errors.to_h
              end
            end
          end
          # save sadata
          @carrier_profile.external_carrier_id = external_id
          @carrier_profile.data['msi_external_id'] = external_id
          @carrier_profile.data['registered_with_msi'] = true
          @carrier_profile.data['registered_with_msi_on'] = Time.current.strftime("%m/%d/%Y %I:%M %p")
          if @carrier_profile.save
            subinsurables = self.query_for_full_hierarchy(exclude_self: false).where(account_id: self.account_id, insurable_type_id: ::InsurableType::RESIDENTIAL_IDS).confirmed
            subinsurables.update_all(preferred_ho4: true)
            subinsurables.each{|si| si.create_carrier_profile(5) unless si.id == self.id }
          end
        end
      end
      # finished successfully
      return nil
    end
	  
	end
end
