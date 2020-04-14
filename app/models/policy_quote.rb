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
	 						quote_attempt[:message] = "Policy #{ policy.number }, has been accepted.  Please check your email for more information."
	 						quote_attempt[:success] = true

	          else
	            # If self.policy, policy_application.policy or 
	            # policy_premium.policy cannot be set correctly
							quote_attempt[:message] = "Error attaching policy to system"
	            update status: 'error'
	          end				  
				  else
				    logger.debug policy.errors
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
	
	def generate_invoices_for_term(renewal = false, refresh = false)
    invoices_generated = false
    
    unless renewal
	    
	    invoices.destroy_all if refresh
	    
	  	if policy_premium.calculation_base > 0 && 
		  	 status == "quoted" && 
		  	 invoices.count == 0
         
        # calculate sum of weights (should be 100, but just in case it's 33+33+33 or something)
        payment_weight_total = policy_application.billing_strategy.new_business['payments'].inject(0){|sum,p| sum + p }.to_d
        payment_weight_total = 100.to_d if payment_weight_total <= 0 # this can never happen unless someone fills new_business with 0s invalidly, but you can't be too careful
        
        # calculate invoice charges
        to_charge = policy_application.billing_strategy.new_business['payments'].map.with_index do |payment, index|
          {
            due_date: index == 0 ? status_updated_on : policy_application.effective_date + index.months,
            fees: (policy_premium.amortized_fees * payment / payment_weight_total).floor + (index == 0 ? policy_premium.deposit_fees : 0),
            total: (policy_premium.calculation_base * payment / payment_weight_total).floor + (index == 0 ? policy_premium.deposit_fees : 0)
          }
        end.select{|tc| tc[:total] > 0 }
        
        # add any rounding errors to the first charge
        to_charge[0][:fees] += policy_premium.total_fees - to_charge.inject(0){|sum,tc| sum + tc[:fees] }
        to_charge[0][:total] += policy_premium.total - to_charge.inject(0){|sum,tc| sum + tc[:total] }
        
        # create invoices
        begin
          ActiveRecord::Base.transaction do
            to_charge.each do |tc|
              invoices.create!({
                due_date:       tc[:due_date],
                available_date: tc[:due_date] - available_period,
                user:           policy_application.primary_user,
                subtotal:       tc[:total] - tc[:fees],
                total:          tc[:total],
                status:         "quoted"
              })
            end
            invoices_generated = true
          end
        rescue ActiveRecord::RecordInvalid => e
          puts e.to_s
        rescue
          puts "Unknown error during invoice creation"
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
