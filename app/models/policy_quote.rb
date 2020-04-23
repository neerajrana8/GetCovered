##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
	include CarrierPensioPolicyQuote
	include CarrierQbePolicyQuote
	include CarrierCrumPolicyQuote
	include ElasticsearchSearchable
  include InvoiceableQuote

  before_save :set_status_updated_on,
  	if: Proc.new { |quote| quote.status_changed? }
  before_validation :set_reference,
  	if: Proc.new { |quote| quote.reference.nil? }

  belongs_to :policy_application, optional: true

  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true

	has_many :events, as: :eventable

	has_many :policy_rates
	has_many :insurable_rates, through: :policy_rates
		
	has_one :policy_premium

	has_many :invoices, as: :invoiceable

  has_many_attached :documents

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

  def bind_policy
    case policy_application.carrier.integration_designation
    when 'qbe'
      set_qbe_external_reference
      qbe_bind
    when 'qbe_specialty'
      { error: 'No policy bind for QBE Specialty' }
    when 'crum'
      crum_bind
    else
      { error: 'Error happened with policy bind' }
    end
  end
  
  def accept
    
	  quote_attempt = {
		  success: false,
		  message: nil,
		  bind_method: "#{ policy_application.carrier.integration_designation }_bind",
		  issue_method: "#{ policy_application.carrier.integration_designation }_issue_policy"
	  }
	  
	  if quoted? || error?
  	  
			self.set_qbe_external_reference if policy_application.carrier.id == 1
		  
			if update(status: "accepted") && start_billing()
			  bind_request = self.send(quote_attempt[:bind_method])
			  
			  unless bind_request[:error]
  			  if policy_application.policy_type.title == "Residential"
    			  policy_number = bind_request[:data][:policy_number]
    			  policy_status = bind_request[:data][:status] == "WARNING" ? "BOUND_WITH_WARNING" : "BOUND"    			  
    		  elsif policy_application.policy_type.title == "Commercial"
    		    policy_number = external_reference
    		    policy_status = "BOUND"
    		  elsif policy_application.policy_type.title == "Rent Guarantee"
    		    policy_number = bind_request[:data][:policy_number]
    		    policy_status = "BOUND"
    		  end

  			  
	    		policy = build_policy(
	      		number: policy_number,
	      		status: policy_status,
	      		billing_status: "CURRENT",
	      		effective_date: policy_application.effective_date,
	      		expiration_date: policy_application.expiration_date,
	      		auto_renew: policy_application.auto_renew,
	      		auto_pay: policy_application.auto_pay,
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
						policy.reload
	      		# Add users to policy
	      		policy_application.policy_users
	      		                  .each do |pu|
	        	  pu.update policy: policy
	        	  pu.user.convert_prospect_to_customer()
	          end
	          
	          # Add insurables to policy
	          policy_application.policy_insurables.update_all policy_id: policy.id
	          
	          # Add rates to policy
	          policy_application.policy_rates.update_all policy_id: policy.id
	          
	          # Add invoices to policy
	          invoices.update_all(invoiceable_id: policy.id, invoiceable_type: 'Policy')
						
		 				build_coverages() if policy_application.policy_type.title == "Residential"
	  
	          if update(policy: policy) && 
	        		 policy_application.update(policy: policy, status: "accepted") && 
	        		 policy_premium.update(policy: policy)
	        		 
	 						PolicyQuoteStartBillingJob.perform_later(policy: policy, issue: quote_attempt[:issue_method])
	 						policy_type_identifier = policy_application.policy_type_id == 5 ? "Rental Guarantee" : "Policy"
	 						quote_attempt[:message] = "#{ policy_type_identifier } ##{ policy.number }, has been accepted.  Please check your email for more information."
	 						quote_attempt[:success] = true

	          else
	            # If self.policy, policy_application.policy or 
	            # policy_premium.policy cannot be set correctly
							quote_attempt[:message] = "Error attaching policy to system"
	            update status: 'error'
	          end				  
				  else
				    logger.debug policy.errors.to_json
				  	quote_attempt[:message] = "Unable to save policy in system"
				  end
				  
				else
  			  quote_attempt[:message] = "Unable to bind policy"	
				end
		  else
		  	quote_attempt[:message] = "Quote billing failed, unable to write policy"
		  end		  
		else
			quote_attempt[:message] = "Quote ineligible for acceptance"
		end
		
		return quote_attempt
  end
	
	def decline
		return_success = false
		if self.update(status: 'declined') && self.policy_application.update(status: "rejected")
		  return_success = true
		end
		return return_success	
	end

	def build_coverages()
		
		policy_application.insurable_rates.each do |rate|
			if rate.schedule == 'liability'
				liability_coverage = self.policy.policy_coverages.new
				liability_coverage.policy_application = self.policy_application
				liability_coverage.designation = 'liability'
				liability_coverage.limit = rate.coverage_limits['liability']
				liability_coverage.deductible = rate.deductibles["all_peril"]
				liability_coverage.special_deductible = rate.deductibles["hurricane"] if rate.deductibles.key?("hurricane")
				liability_coverage.enabled = true
				
				medical_coverage = self.policy.policy_coverages.new
				medical_coverage.policy_application = self.policy_application
				medical_coverage.designation = 'medical'
				medical_coverage.limit = rate.coverage_limits['medical']
				medical_coverage.deductible = rate.deductibles["all_peril"]
				medical_coverage.special_deductible = rate.deductibles["hurricane"] if rate.deductibles.key?("hurricane")
				medical_coverage.enabled = true

				liability_coverage.save
				medical_coverage.save
			elsif rate.schedule == 'coverage_c'
				coverage = self.policy.policy_coverages.new
				coverage.policy_application = self.policy_application
				coverage.designation = rate.schedule
				coverage.limit = rate.coverage_limits[rate.schedule]
				coverage.deductible = rate.deductibles["all_peril"]
				coverage.special_deductible = rate.deductibles["hurricane"] if rate.deductibles.key?("hurricane")
				coverage.enabled = true
				
				coverage_d = self.policy.policy_coverages.new
				coverage_d.policy_application = self.policy_application
				coverage_d.designation = "loss_of_use"
				coverage_d.limit = rate.coverage_limits[rate.schedule] * 0.2
				coverage_d.deductible = rate.deductibles["all_peril"]
				coverage_d.special_deductible = rate.deductibles["hurricane"] if rate.deductibles.key?("hurricane")
				coverage_d.enabled = true
				
				coverage.save
				coverage_d.save
			elsif rate.schedule == 'optional'
				designation = nil
				
				if rate.sub_schedule == "policy_fee"
					designation = "qbe_fee"
				else
					designation = rate.sub_schedule
				end
				
				coverage = self.policy.policy_coverages.new
				coverage.policy_application = self.policy_application
				coverage.designation = designation
				coverage.limit = rate.coverage_limits["coverage_c"]
				coverage.deductible = rate.deductibles["all_peril"]
				coverage.special_deductible = rate.deductibles["hurricane"] if rate.deductibles.key?("hurricane")
				coverage.enabled = true
				
				coverage.save
			end
		end
	end

  def start_billing

    billing_started = false
        
		if policy.nil? && 
			 policy_premium.calculation_base > 0 && 
			 status == "accepted"
			 
	    invoices.order("due_date").each_with_index do |invoice, index|
		  	invoice.update status: index == 0 ? "available" : "upcoming"
		  end		
			 
			charge_invoice = invoices.order("due_date").first.pay(stripe_source: :default)
																
      if charge_invoice[:success] == true
        return true
      end
															
		end    
		
#     if !policy.nil? && policy_premium.calculation_base > 0 && status == "accepted"
# 			     
# 	    invoices.order("due_date").each_with_index do |invoice, index|
# 		  	invoice.update status: index == 0 ? "available" : "upcoming",
# 		  								 policy: policy
# 		  end
# 		  
# 		  charge_invoice = invoices.order("due_date").first.pay(stripe_source: policy_application.primary_user().payment_profiles.first.source_id)
# 		  
#       if charge_invoice[:success] == true
#         policy.update billing_status: "CURRENT"
#         return true
#       else
#         policy.update billing_status: "ERROR"
#       end
# 		  
#     end
    
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
  	      parent_entity = account.nil? ? agency : account
	        self.reference = "#{parent_entity.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true
	        
	        break unless PolicyQuote.exists?(:reference => self.reference)
	      end
	    end
	    
	    return return_status	  	  
	  end

end
