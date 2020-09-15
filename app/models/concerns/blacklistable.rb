# =Blacklistable Functions Concern
# file: +app/models/concerns/blacklistable.rb+

module Blacklistable
  extend ActiveSupport::Concern
    
  # Toggle Blacklist
  #
  # Adds or removes a zipcode from blacklist hash
  #
  # Params:
  # +zip_code+:: (integer)
  #
  # Example:
  #   @carrier_policy_type_availability = CarrierPolicyTypeAvailability.find(1)
  #   @carrier_policy_type.toggle_blacklist(90034)
  #   => { success: true, action: "add" }
  
  def toggle_blacklist(zip_code = nil)
    raise ArgumentError, 'Argument "zip_code" cannot be nil' if zip_code.nil?
    
    zip_code = zip_code.to_s # Change Zip Code to string for Json
    
    response = { success: false, action: nil }
          
    if zip_code_blacklist.key?(zip_code)
      zip_code_blacklist.delete(zip_code)
      response[:action] = 'remove'
    else
      zip_code_blacklist[zip_code] = []
      response[:action] = 'add'
    end
    
    response[:success] = true if save
    
    response
  end
    
  # Toggle Plus Four
  #
  # Adds or removes a zipcode plus four from blacklist hash
  # if zipcode does not appear in hash it is added first
  #
  # Params:
  # +zip_code+:: (integer)
  # +plus_four+:: (integer)
  #
  # Example:
  #   @carrier_policy_type_availability = CarrierPolicyTypeAvailability.find(1)
  #   @carrier_policy_type.toggle_plus_four(90034, 5204)
  #   => { success: true, action: "add" }
  
  def toggle_plus_four(zip_code = nil, plus_four = nil)
    raise ArgumentError, 'Argument "zip_code" cannot be nil' if zip_code.nil?
    raise ArgumentError, 'Argument "plus_four" cannot be nil' if plus_four.nil?
    
    zip_code = zip_code.to_s # Change Zip Code to string for Json
    plus_four = plus_four.to_s # Change Plus Four to string for Json
    
    response = { success: false, action: nil }
    
    toggle_blacklist(zip_code) unless zip_code_blacklist.key?(zip_code)
    
    if zip_code_blacklist[zip_code].include?(plus_four)
      zip_code_blacklist[zip_code].delete
      response[:action] = 'remove'
    else
      zip_code_blacklist[zip_code] << plus_four
      response[:action] = 'add'
     end
    
    response[:success] = true if save
    
    response
  end
    
  # On Blacklist?
  #
  # Returns bool if zipcode or plus four is included
  # in zip_code_blacklist
  #
  # Params:
  # +zip_code+:: (integer)
  # +plus_four+:: (integer)
  #
  # Example:
  #   @carrier_policy_type_availability = CarrierPolicyTypeAvailability.find(1)
  #   @carrier_policy_type.on_blacklist?(90034, 5204)
  #   => true / false

  def on_blacklist?(zip_code = nil, plus_four = nil)
    raise ArgumentError, 'Argument "zip_code" cannot be nil' if zip_code.nil?
    
    zip_code = zip_code.to_s # Change Zip Code to string for Json
    plus_four = plus_four.to_s unless plus_four.nil? # Change Plus Four to string for Json
    
    result = false
      
    if zip_code_blacklist.key?(zip_code)
      if zip_code_blacklist[zip_code].nil?
        result = true 
      else
        raise ArgumentError, "Argument 'plus_four' required for zip_code: #{zip_code}" if plus_four.nil?

        result = true if zip_code_blacklist[zip_code].include?(plus_four)
      end  
    end
      
    result  
  end
end
