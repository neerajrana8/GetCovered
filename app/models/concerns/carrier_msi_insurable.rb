##
# =MSI Insurable Functions Concern
# file: +app/models/concerns/carrier_msi_insurable.rb+

module CarrierMsiInsurable
  extend ActiveSupport::Concern

  included do
	  
    def register_with_msi
      # load the stuff we need
      return ["Insurable must be a residential community"] if self.insurable_type.title != "Residential Community"
	    @carrier = Carrier.where(title: 'Millennial Services Insurance').take
      return ["Unable to load carrier information"] if @carrier.nil?
	    @carrier_profile = carrier_profile(@carrier.id)
      return ["Unable to load carrier profile"] if @carrier_profile.nil?
	    @address = primary_address()
	    return ["Community lacks a primary address"] if @address.nil?
      # try to build the request
      event = events.new(
        verb: 'post',
        format: 'xml',
        interface: 'REST',
        endpoint: Rails.application.credentials.msi[:uri][ENV["RAILS_ENV"].to_sym]
      )
      # MOOSE WARNING figure out what to do with CarrierAgency external id
      msi_service = MsiService.new
      errors_returned = msi_service.build_request(:get_or_create_community,
        effective_date:                 Time.current.to_date + 1.day,
        
        community_name:                 self.title,
        number_of_units:                units.count,
        property_manager_name:          account.title, # MOOSE WARNING: should this instead be in the carrier insurable profile?
        years_professionally_managed:   @carrier_profile.traits['professionally_managed'] ?
                                          (@carrier_profile.traits['professionally_managed_year'].nil? ?
                                            6 :
                                            Time.current.year + 1 - @carrier_profile.traits['professionally_managed_year'].to_i, # +1 so that we round up instead of down
                                          ) :
                                          0
        year_built:                     @carrier_profile.traits['construction_year'],
        gated:                          @carrier_profile.traits['gated'],
        
        address_line_one:               @address.combined_street_address, # yes?
        city:                           @address.city,
        state:                          @address.state,
        zip:                            @address.zip_code
      )
      if errors
        return errors_returned.map{|err| "Service call error: #{err}" }
      end
      event.request = msi_service.compiled_rxml
      # try to execute the request
      if !event.save
        return ["Failed to save service call status-tracking Event"]
      else
        # execute & log
        event.started = Time.now
        msi_data = msi_service.call
        event.completed = complete_time        
        event.response = msi_data[:data]
        event.status = msi_data[:error] ? 'error' : 'success'
        unless event.save
          return ["Failed to save response to service call status-tracking Event"]
        end
        # handle response
        if msi_data[:error]
          return ["Service call resulted in error"] # MOOSE WARNING: make service store easily-accessible error message & pull it here
        else
          # grab the id
          external id = msi_data[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "MSI_CommunityInfo", "MSI_CommunityID")
          if external_id.nil?
            return ["Successful service call did not return an id"]
          end
          @carrier_profile.update_columns(external_carrier_id: external_id)
          # handle address corrections MOOSE WARNING: fix up the address and store fixes in profile_data (address_corrected and address_correction_data)
          # address info: msi_data[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "MSI_CommunityInfo", "Addr") # DetailAddr etc
          @carrier_profile.external_carrier_id = external_id
          @carrier_profile.data['msi_external_id'] = external_id
          @carrier_profile.data['registered_with_msi'] = true
          @carrier_profile.data['registered_with_msi_on'] = Time.current.strftime("%m/%d/%Y %I:%M %p")
          @carrier_profile.save
        end
      end
      # finished successfully
      return nil
    end
	  
	end
end
