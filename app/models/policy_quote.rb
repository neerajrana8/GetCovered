##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  Concerns
	include CarrierQbePolicyQuote
	include CarrierCrumPolicyQuote
	include ElasticsearchSearchable

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

	has_many :invoices

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
	    		policy = build_policy(
	      		number: bind_request[:data][:policy_number],
	      		status: bind_request[:data][:status] == "WARNING" ? "BOUND_WITH_WARNING" : "BOUND",
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
	          invoices.update_all policy_id: policy.id
						
		 				build_coverages() if policy_application.policy_type.title == "Residential"
	  
	          if update(policy: policy) && 
	        		 policy_application.update(policy: policy, status: "accepted") && 
	        		 policy_premium.update(policy: policy)
	        		 
	 						PolicyQuoteStartBillingJob.perform_later(policy: policy, issue: quote_attempt[:issue_method])
	 						quote_attempt[:message] = "Policy #{ policy.number }, has been accepted.  Please check your email for more information."
	 						quote_attempt[:success] = true

	          else
	            # If self.policy, policy_application.policy or 
	            # policy_premium.policy cannot be set correctly
							quote_attempt[:message] = "Error attaching policy to system"
	            update status: 'error'
	          end				  
				  else
				  	quote_attempt[:message] = "Unable to save policy in system"
				  	puts events.last.response
				  	logger.debug policy.errors
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
	
	def generate_invoices_for_term(renewal = false, refresh = false)
    invoices_generated = false
    
    unless renewal
	    
	    invoices.destroy_all if refresh
	    
	  	if policy_premium.calculation_base > 0 && 
		  	 status == "quoted" && 
		  	 invoices.count == 0
		  	
		  	payment_count = policy_application.billing_strategy.new_business['payments'].select { |p| p > 0 }.count
		  	
		  	amortized_fees_per_payment = policy_premium.amortized_fees / payment_count
		  	
		  	policy_application.billing_strategy.new_business['payments'].each_with_index do |payment, index|
					next if payment == 0
					
			  	amount = policy_premium.calculation_base * (payment.to_f / 100)
					fees = index == 0 ? amortized_fees_per_payment + policy_premium.deposit_fees : amortized_fees_per_payment
					due_date = index == 0 ? status_updated_on : policy_application.effective_date + index.months

	        invoice = invoices.new do |inv|
	          inv.due_date        = due_date
	          inv.available_date  = due_date + available_period
	          inv.user            = policy_application.primary_user
	          inv.subtotal        = amount
	          inv.total           = amount + fees
	          inv.status          = "quoted"
	        end	
	        
	        unless invoice.save
	          pp invoice.errors
	        end
	        				
				end
				
				invoices_generated = true if invoices.count == payment_count
				totals = invoices.map(&:total)
				total = totals.inject { |r, t| r + t }
				difference = policy_premium.total - total
				
				if total > 0
					invoices.order("due_date").last.update total: invoices.last.total + difference	
				end 
				
		  end
	  else
	  	# Set up Renewal Invoice Generation
	  end
    
    return invoices_generated
    
  end

  def start_billing

    billing_started = false
        
		if policy.nil? && 
			 policy_premium.calculation_base > 0 && 
			 status == "accepted"
			 
	    invoices.order("due_date").each_with_index do |invoice, index|
		  	invoice.update status: index == 0 ? "available" : "upcoming"
		  end		
			 
			charge_invoice = invoices.order("due_date").first.pay(stripe_source: policy_application.primary_user().payment_profiles.first.source_id)
																
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
