##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
  include CarrierQbePolicyQuote, ElasticsearchSearchable
  # include ElasticsearchSearchable

  before_save :set_status_updated_on,
  	if: Proc.new { |quote| quote.status_changed? }
  before_validation :set_reference,
  	if: Proc.new { |quote| quote.reference.nil? }

  belongs_to :policy_application, optional: true

  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true

	has_many :events,
	    as: :eventable

	has_many :policy_rates
	has_many :insurable_rates,
		through: :policy_rates

	has_one :policy_premium

	accepts_nested_attributes_for :policy_premium

  enum status: { awaiting_estimate: 0, estimated: 1, quoted: 2, 
                 quote_failed: 3, accepted: 4, declined: 5, 
                 abandoned: 6, expired: 7, error: 8 }

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end

	def mark_successful
  	policy_application.update status: 'quoted' if update status: 'quoted'
  end
  
  def mark_failure
  	policy_application.update status: 'quote_failed' if update status: 'quote_failed'
  end

  def available_period
    7.days
  end
  
  def accept
		success = false
		method = "#{ policy_application.carrier.integration_designation }_bind"
		
		if quoted? || error?
    			
  		policy = build_policy(
    		effective_date: policy_application.effective_date,
    		expiration_date: policy_application.expiration_date,
    		auto_renew: true,
    		auto_pay: true,
    		policy_in_system: true,
    		system_purchased: true,
    		billing_enabled: true,
    		serviceable: policy_application.carrier.syncable,
    		policy_type: policy_application.policy_type,
    		agency: policy_application.agency,
    		account: policy_application.account,
    		carrier: policy_application.carrier
  		)
  		
  		if policy.save
    		policy.reload()
    		
    		# Add users to policy
    		policy_application.policy_users
    		                  .each do |pu|
      	  pu.update policy: policy	
        end
        
        # Add insurables to policy
        policy_application.policy_insurables
                          .each do |pi|
          pi.update policy: policy
        end
        
        # Add rates to policy
        policy_rates.each do |pr|
          pr.update policy: policy  
        end
    		
        if update(policy: policy, status: "accepted") && 
      		 policy_application.update(policy: policy) && 
      		 policy_premium.update(policy: policy)
           
      		if start_billing()
      			success = true # if self.send(method)
      		end       
        
        else
          # If self.policy, policy_application.policy or 
          # policy_premium.policy cannot be set correctly
          update status: 'error'
        end
      else
        # If policy cannot be created      
        update status: 'error'
        pp policy.errors
      end
		
		end
		
		return success
	end
	
	def decline
		success = self.update status: 'declined' ? true : false
		return success	
	end

  def start_billing
#    return false unless policy.in_system?

    billing_started = false
    
    puts !policy.nil?
    puts policy_premium.total > 0
    puts accepted?
    
    if !policy.nil? && policy_premium.total > 0 && status == "accepted"
      policy_application.billing_strategy.new_business['payments'].each_with_index do |payment, index|
        amount = policy_premium.total * (payment.to_f / 100)
        next if amount == 0

        # Due date is today for the first invoice. After that it is due date
        # after effective date of the policy
        due_date = index == 0 ? status_updated_on : policy.effective_date + index.months
        invoice = policy.invoices.new do |inv|
          inv.due_date        = due_date
          inv.available_date  = due_date + available_period
          inv.user            = policy_application.primary_user
          inv.subtotal        = amount
          inv.total           = amount
        end
        unless invoice.save
          pp invoice.errors
        end
      end

#       charge_invoice = policy.invoices.first.pay(allow_upcoming: true)
# 
#       if charge_invoice[:success] == true
#         return true
#       end

    end
    billing_started
  end

  private
    def set_status_updated_on
	    self.status_updated_on = Time.now
	  end

    def set_reference
	    return_status = false

	    if reference.nil?

	      loop do
	        self.reference = "#{account.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true

	        break unless PolicyQuote.exists?(:reference => self.reference)
	      end
	    end

	    return return_status
	  end

end
