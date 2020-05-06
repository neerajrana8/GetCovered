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
        effective_date:                 Time.current.to_date, # MOOSE WARNING: dunno what this means so dunno what it should be!
        
        community_name:                 self.title,
        number_of_units:                units.count,
        sales_rep_id:                   @carrier_profile.traits['community_sales_rep_id'], # MOOSE WARNING: dunno what this means
        property_manager_name:          account.title, # MOOSE WARNING: should this instead be in the carrier insurable profile?
        years_professionally_managed:   @carrier_profile.traits['professionally_managed_year'].nil? ?
                                          6 :
                                          Time.current.year + 1 - @carrier_profile.traits['professionally_managed_year'].to_i, # +1 so that we round up instead of down
                                          # MOOSE WARNING: add a 'professionally managed' field and handle this differently?
        year_built:                     @carrier_profile.traits['construction_year'],
        gated?:                         @carrier_profile.traits['gated'],
        
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
        # execute
        event.started = Time.now
        msi_data = msi_service.call
        event.completed = complete_time
        # handle response
        
      end
    
    end
	  
	end
end
