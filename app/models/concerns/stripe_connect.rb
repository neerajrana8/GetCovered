# Stripe Connect Concern
# file: +app/models/concerns/stripe_connect.rb+

module StripeConnect
  extend ActiveSupport::Concern

  # Create Stripe Connect Account
  #
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.create_stripe_connect_account
  #   => true
  #

  def create_stripe_connect_account
    
    return false if prevent_for_master
    
    if owned? && stripe_id.nil?
      
      profile = owner.profile
    
      begin
        
        stripe_account = Stripe::Account.create(
          :type => 'custom',
          :country => 'US',
          :business_name => title,
          :email => owner.email,
          :legal_entity => {
            :first_name => profile.first_name,
            :last_name => profile.last_name,
            :type => "company"
          }
        )

      rescue Stripe::APIConnectionError,
             Stripe::StripeError,
             Stripe::APIError => e
        
        # Need to create an action to add to queue for later processing
        # pp e
        
      end
      
      unless stripe_account.nil? || 
             stripe_account["id"].nil?
        output_request_to_logs("SUCCESS", "create_stripe_connect_account")
        update(stripe_id: stripe_account["id"])
      else
        output_request_to_logs("ERROR", "create_stripe_connect_account")
      end
      
    end
  end
  
  # Validate Stripe Connect Account
  #
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.verify_stripe_connect_account(args)
  #
  #
  # Arguments:
  #   args: (Hash)
  #   args[:business_name]: (String)
  #   args[:business_name]: (String)
  #   args[:personal_id_number]: (String)
  #   args[:file]: (String) file path to stripe identity_document
  
  def validate_stripe_connect_account(args = nil)
    
    return false if prevent_for_master
    
    if stripe_id.nil?
      create_stripe_connect_account()
      __method__
    end
    
    options = {
      :business_tax_id => nil,
      :business_name => nil,
      :personal_id_number => nil,
      :file => nil
    }.merge!(args)
    
    if owned? && 
       !stripe_id.nil?
      
      profile = owner.profile
      
      stripe_account_instance = Stripe::Account.retrieve(stripe_id)
      
      stripe_account_instance.legal_entity.address = {
        :city => address.locality,
        :line1 => address.combined_street_address,
        :postal_code => address.combined_postal_code,
        :state => address.region
      }
      
      if tos_accepted?
        if stripe_account_instance["tos_acceptance"]["date"].nil? || 
           stripe_account_instance["tos_acceptance"]["ip"].nil?
          
          stripe_account_instance["tos_acceptance"]["date"] = tos_acceptance_date.nil? ? nil : 
                                                                                         tos_acceptance_date.to_i
          stripe_account_instance["tos_acceptance"]["ip"] = tos_acceptance_ip
        
        end
      end
      
      stripe_account_instance["legal_entity"]["business_name"] = options[:business_name] unless options[:business_name].nil?
      stripe_account_instance["legal_entity"]["business_tax_id"] = options[:business_tax_id] unless options[:business_tax_id].nil?
      stripe_account_instance["legal_entity"]["dob"]["day"] = profile.birth_date.strftime("%-d") if stripe_account_instance["legal_entity"]["dob"]["day"].nil?
      stripe_account_instance["legal_entity"]["dob"]["month"] = profile.birth_date.strftime("%-m") if stripe_account_instance["legal_entity"]["dob"]["month"].nil?
      stripe_account_instance["legal_entity"]["dob"]["year"] = profile.birth_date.strftime("%Y") if stripe_account_instance["legal_entity"]["dob"]["year"].nil?
      stripe_account_instance["legal_entity"]["personal_id_number"] = options[:personal_id_number] unless options[:personal_id_number].nil?
      
      unless options[:file].nil?
        
        identity_document = Stripe::FileUpload.create(
          :purpose => 'identity_document',
          :file => File.new("#{Rails.root.to_s}#{options[:file]}")
        )
        
        stripe_account_instance["legal_entity"]["verification"]["document"] = identity_document["id"] unless identity_document["id"].nil?
        
      end
        
      output_request_to_logs("SUCCESS", "validate_stripe_connect_account")
      
      stripe_account_instance.save
      
    end  
  end
  
  # Retrieve External Accounts
  #
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.retrieve_external_accounts
  #   => #<Stripe::ListObject> JSON: { stripe_data }
  
  def retrieve_external_accounts
    
    return false if prevent_for_master
    
    if owned? && 
       !stripe_id.nil?
        
      output_request_to_logs("SUCCESS", "retrieve_external_accounts")
      
      stripe_account_instance = stripe_account
      return stripe_account_instance.external_accounts.all(:limit => 100, :object => "bank_account")
    
    end
  end
  
  # Add External Account
  #
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.add_external_account(args)
  #
  #
  # Arguments:
  #   args: (Hash)
  #   args[:object]: (String)
  #   args[:country]: (String)
  #   args[:currency]: (String)
  #   args[:routing_number]: (String)
  #   args[:account_number]: (String)
  
  def add_external_account(args = nil)
    
    return false if prevent_for_master
    
    options = {
      :object => nil,
      :country => nil,
      :currency => nil,
      :routing_number => nil,
      :account_number => nil
    }.merge!(args)
    
    if owned? && 
       !stripe_id.nil? &&
       !options[:object].nil? &&
       !options[:country].nil? &&
       !options[:currency].nil? &&
       !options[:routing_number].nil?  &&
       !options[:account_number].nil?
      
      stripe_account_instance = stripe_account
      stripe_account_instance["external_account"] = options
        
      output_request_to_logs("SUCCESS", "add_external_account")
      
      stripe_account_instance.save
    
    end
  end
  
  # Delete External Account
  #
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.delete_external_account(external_account_id)
  #
  #
  # Arguments:
  #   external_account_id: (string)
  
  def delete_external_account(external_account_id = nil)
    
    return false if prevent_for_master
    
    if owned? && 
       !stripe_id.nil? &&
       !external_account_id.nil?
      
      stripe_account_instance = stripe_account
      stripe_account_instance.external_accounts
                             .retrieve(external_account_id)
                             .delete()
        
      output_request_to_logs("SUCCESS", "delete_external_account")
    
    end
  end
  
  # Stripe Account Status
  #
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.stripe_account_status
  #   => { 
  #   =>    "details": null, 
  #   =>    "details_code" : null, 
  #   =>    "document" : null, 
  #   =>    "status" : "pending" 
  #   => }
  
  def stripe_account_verification_status
    
    return false if prevent_for_master
    
    unless stripe_id.nil?
      
      stripe_account_instance = Stripe::Account.retrieve(stripe_id)
      
      update verified: true, charges_enabled: true if stripe_account_instance["legal_entity"]["verification"]["status"] == "verified"
        
      output_request_to_logs("SUCCESS", "stripe_account_verification_status")
      
      return stripe_account["legal_entity"]["verification"]["status"]
    end  
  end 
  
  # Stripe Account
  # 
  # Example:
  #   >> @agency = Agency.find(1)
  #   >> @agency.stripe_account
  #   => #<Stripe::Account id=acct_*> JSON: { stripe_data }
  
  def stripe_account
    
    return false if prevent_for_master
    
    if owned? && 
       !stripe_id.nil? 
      
      output_request_to_logs("SUCCESS", "stripe_account")
      
      return Stripe::Account.retrieve(stripe_id)
      
    end
  end
  
  private
    
    def prevent_for_master
      if respond_to?(:master_agency) && 
         master_agency == true
        return true
      else
        return false
      end
    end
    
    def output_request_to_logs(status = "ERROR", action = nil)
      unless action.nil?
        
        display_status_color = status == "ERROR" ? :red : :green
        puts "#{ "[".yellow } #{ "Stripe Connect Service".blue } #{ "]".yellow }#{ "[".yellow } #{ "#{ self.class.name.upcase }: #{id}".blue } #{ "]".yellow }#{ "[".yellow } #{status.colorize(display_status_color)} #{ "]".yellow }: #{ action.blue }"
      
      end
    end
    
end
