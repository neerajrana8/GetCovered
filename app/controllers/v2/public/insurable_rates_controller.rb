##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class InsurableRatesController < PublicController
	  
	  	def index
		  	
		  	@insurable = Insurable.find(params[:id])
		  	@address = @insurable.primary_address()
		  	@rates = {}
		  	
        # get the billing period, either from a string or from a BillingStrategy id
        billing_period = "month"
        if params[:billing_period].presence?
          billing_strategy = (Integer(params[:billing_period]) rescue 0)
          billing strategy = billing_strategy == 0 ? nil : ::BillingStrategy.where(id: billing_strategy).take
          if billing_strategy.nil?
            billing_period = params[:billing_period].downcase.sub(/ly/, '').gsub('-', '_') if params[:billing_period].class == ::String
          else
            billing_period = { 1 => "annual", 2 => "bi_annual", 4 => "quarter", 12 => "month" }[billing_strategy.new_business["payments_per_term"]]
            billing_period = 'month' if billing_period.nil?
          end
        end
        # get other params and go wild
		  	insured_count = params[:number_insured].presence ? params[:number_insured] : 1
		  	deductible = params[:deductible].presence ? Integer(params[:deductible]) * 100 : @address.state == "FL" ? 50000 : 25000
		  	hurricane = params[:hurricane].presence ? Integer(params[:hurricane]) * 100 : @address.state == "FL" ? 50000 : nil
		  	
		  	query = @address.state == "FL" ? "(deductibles ->> 'all_peril')::integer = #{ deductible } AND (deductibles ->> 'hurricane')::integer = #{ hurricane }" : "(deductibles ->> 'all_peril')::integer = #{ deductible }"
		  	
		  	@rates["coverage_c"] = @insurable.insurable_rates
		  										 							 .coverage_c
													 							 .activated
													 							 .where(number_insured: insured_count, interval: billing_period, enabled: true)
													 							 .where(query)
		  	
		  	@rates["liability"] = @insurable.insurable_rates
									  										.liability
									  									  .activated
									  										.where(number_insured: insured_count, interval: billing_period, enabled: true)		
		  	
		  	@rates["optional"] = @insurable.insurable_rates
 	  							  									 .optional
  								  									 .activated
								  										 .where(number_insured: insured_count, interval: billing_period, enabled: true)
								  										 .where.not(sub_schedule: "policy_fee")
		  										 		  		      
	      render json: @rates.to_json,
	             status: :ok
	      
		  end
	   
	  end
	end
end
