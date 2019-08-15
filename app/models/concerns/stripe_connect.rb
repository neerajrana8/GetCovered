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
    
    if stripe_id.nil?
      
      profile = staff.first.profile
			
			request = {
        :type => 'custom',
        :country => 'US',
        :business_name => title,
        :email => owner.email,
        :legal_entity => {
          :first_name => profile.first_name,
          :last_name => profile.last_name,
          :type => "company"
        }				
			}
			
      event = events.new(
        verb: 'post', 
        format: 'json', 
        interface: 'REST',
        process: 'stripe_connect_create_account', 
        endpoint: 'https://api.stripe.com/v1/accounts',
        request: request,
        started: Time.now
      ) 
    
      begin
        
        stripe_account = Stripe::Account.create(request)

      rescue Stripe::APIConnectionError,
             Stripe::StripeError,
             Stripe::APIError => e
        
        # Need to create an action to add to queue for later processing
        event.respone = e
        event.status = 'error'
        
      end
      
      event.completed = Time.now
      
      unless stripe_account.nil? || 
             stripe_account["id"].nil?
        
        event.status = 'success'
        event.response = stripe_account
        
        output_request_to_logs("SUCCESS", "create_stripe_connect_account")
        update(stripe_id: stripe_account["id"])
      else
        output_request_to_logs("ERROR", "create_stripe_connect_account")
      end
      
      event.save
      
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
      :file => nil,
      :ip_address => nil
    }.merge!(args)
    
    puts "\n\nIP ADDRESS NULL\n".red if options[:ip_adress].nil?			    
    options[:ip_adress] = '127.0.0.1'
    puts "\nIP ADDRESS COULD NOT BE ASSIGNED\n\n".red if options[:ip_adress].nil?
    puts "\nIP ADDRESS ASSIGNED\n\n".green if !options[:ip_adress].nil?
    			    
    if !stripe_id.nil? 
      
      profile = owner.profile

	    event = events.new(
	      verb: 'post', 
	      format: 'json', 
	      interface: 'REST',
	      process: 'stripe_connect_validate_account', 
	      endpoint: 'https://api.stripe.com/v1/accounts',
	      request: options,
	      started: Time.now
	    )
 
      begin
        
        stripe_account_instance = Stripe::Account.retrieve(stripe_id)

      rescue Stripe::APIConnectionError,
             Stripe::StripeError,
             Stripe::APIError => e
        
        # Need to create an action to add to queue for later processing
        pp e
        event.response = e
        event.status = 'error'
        
      end
      
      unless event.status == 'error'
	      
        event.response = stripe_account_instance
        event.status = 'success'

	      stripe_account_instance.legal_entity.address = {
	        :city => primary_address.city,
	        :line1 => primary_address.combined_street_address,
	        :postal_code => primary_address.combined_zip_code,
	        :state => primary_address.state
	      }
	      
	      if tos_accepted?
	        if stripe_account_instance["tos_acceptance"]["date"].nil? || 
	           stripe_account_instance["tos_acceptance"]["ip"].nil?
	          
	          stripe_account_instance["tos_acceptance"]["date"] = tos_accepted_at.nil? ? nil : 
	                                                                                         tos_accepted_at.to_i
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
	      
	      pp stripe_account_instance
	      
	      stripe_account_instance.save
	      
	    end
      
      event.save()
      
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
    
    if !stripe_id.nil?
        
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
    
    if !stripe_id.nil? &&
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
    
    if !stripe_id.nil? &&
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
    
    if !stripe_id.nil? 
      
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
