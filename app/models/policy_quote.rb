##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
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
  
  def build_new_policy
    build_policy(
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
      carrier: policy_application.carrier,
      policy_users: policy_application.policy_users,
      policy_insurables: policy_application.policy_insurables,
      policy_rates: policy_application.policy_rates,
      policy_application: policy_application,
      policy_premiums: [policy_premium]
    )
  end
  
  def accept
    return false unless quoted?

    policy = build_new_policy
    if policy.save             
      build_coverages if policy_application.policy_type.title == 'Residential'

      if update(policy: policy, status: 'accepted') && start_billing
        bind_request = bind_policy
				if bind_request[:error]
					update status: 'error'
          return false
        else
          policy.update(bind_request[:data][:policy_number], bind_request[:data][:status] == "WARNING" ? "BOUND_WITH_WARNING" : "BOUND")
					issue = "#{ policy_application.carrier.integration_designation }_issue_policy"
          PolicyQuoteStartBillingJob.perform_later(policy: policy, issue: issue)
          return true
        end
        
      else
        update status: 'error'
      end
    else
      update status: 'error'
    end
    false
  end

  
  # def accept
	# 	success = false
	# 	method = "#{ policy_application.carrier.integration_designation }_bind"
	# 	issue = "#{ policy_application.carrier.integration_designation }_issue_policy"
		
	# 	if quoted? || error?
	# 		self.set_qbe_external_reference if policy_application.carrier.id == 1 
	# 		bind_request = self.send(method)
      
  #     unless bind_request[:error]
	      
  #   		policy = build_policy(
  #     		number: bind_request[:data][:policy_number],
  #     		status: bind_request[:data][:status] == "WARNING" ? "BOUND_WITH_WARNING" : "BOUND",
  #     		effective_date: policy_application.effective_date,
  #     		expiration_date: policy_application.expiration_date,
  #     		auto_renew: policy_application.auto_renew,
  #     		auto_pay: policy_application.auto_pay,
  #     		policy_in_system: true,
  #     		system_purchased: true,
  #     		billing_enabled: true,
  #     		serviceable: policy_application.carrier.syncable,
  #     		policy_type: policy_application.policy_type,
  #     		agency: policy_application.agency,
  #     		account: policy_application.account,
  #     		carrier: policy_application.carrier
  #   		)      

  #   		if policy.save
	# 				policy.reload()
      		
  #     		# Add users to policy
  #     		policy_application.policy_users
  #     		                  .each do |pu|
  #       	  pu.update policy: policy
  #       	  pu.user.convert_prospect_to_customer()
  #         end
          
  #         # Add insurables to policy
  #         policy_application.policy_insurables
  #                           .each do |pi|
  #           pi.update policy: policy
  #         end
          
  #         # Add rates to policy
  #         policy_application.policy_rates.each do |pr|
  #           pr.update policy: policy
	# 				end
					
	# 				build_coverages() if policy_application.policy_type.title == "Residential"
  
  #         if update(policy: policy, status: "accepted") && 
  #       		 policy_application.update(policy: policy) && 
  #       		 policy_premium.update(policy: policy)
             
  #       		if start_billing()
	# 						PolicyQuoteStartBillingJob.perform_later(policy: policy, issue: issue)
  #       			success = true # if self.send(method)
  #       		end       
          
  #         else
  #           # If self.policy, policy_application.policy or 
  #           # policy_premium.policy cannot be set correctly
  #           update status: 'error'
  #         end
  #       else
  #         # If policy cannot be created      
  #         update status: 'error'
  #         logger.debug policy.errors
  #       end
  #     else
      
  #     end
	# 	end
		
	# 	return success
	# end
	
	def decline
		success = self.update status: 'declined' ? true : false
		return success	
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
	
	def generate_invoices_for_term(renewal = false)
    
    invoices_generated = false
    
    unless renewal
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
    
    if !policy.nil? && policy_premium.calculation_base > 0 && status == "accepted"
	     
	    invoices.order("due_date").each_with_index do |invoice, index|
		  	invoice.update status: index == 0 ? "available" : "upcoming",
		  								 policy: policy
		  end
		  
		  charge_invoice = invoices.order("due_date").first.pay(stripe_source: policy_application.primary_user().payment_profiles.first.source_id)
		  
		  pp charge_invoice
		  
      if charge_invoice[:success] == true
        policy.update billing_status: "CURRENT"
        return true
      else
        policy.update billing_status: "ERROR"
      end
		  
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
  	      parent_entity = account.nil? ? agency : account
	        self.reference = "#{parent_entity.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true
	        
	        break unless PolicyQuote.exists?(:reference => self.reference)
	      end
	    end
	    
	    return return_status	  	  
	  end

end
