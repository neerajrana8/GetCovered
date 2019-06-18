# =Blacklistable Functions Concern
# file: +app/models/concerns/blacklistable.rb+

module Blacklistable
  extend ActiveSupport::Concern

  included do
    # Toggle Blacklist
    #
    # Adds or removes a zipcode from blacklist array
    #
  	# Params:
    # +zip_code+:: (integer)
    #
    # Example:
    #   @carrier_policy_type_availability = CarrierPolicyTypeAvailability.find(1)
    #   @carrier_policy_type.toggle_blacklist(90034)
    #   => { success: true, action: "add" }
    
    def toggle_blacklist(zip_code = nil)
      response = { success: false, action: nil }
      
      unless zip_code.nil?
        if zip_code_blacklist.include?(zip_code)
          zip_code_blacklist.delete(zip_code)
          response[:action] = "remove"
        else
          zip_code_blacklist << zip_code
          response[:action] = "add"
        end
        
        response[:success] = true if save()
      end
      
      return response
    end    
  end
end