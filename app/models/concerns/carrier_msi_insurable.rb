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
      
      
      
      
      
      
	    unless @address.nil? ||
	           @carrier_profile.data["county_resolved"] == true
	      # When an @address and county resolved
    
    end
	  
	end
end
