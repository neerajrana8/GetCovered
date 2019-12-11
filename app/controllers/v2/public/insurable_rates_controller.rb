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
		  	
		  	insured_count = params[:number_insured].presence ? params[:number_insured] : 1
		  	billing_period = params[:billing_period].presence ? params[:billing_period].downcase.sub(/ly/, '').gsub('-', '_') :
		  																											"month"
		  	deductible = params[:deductible].presence ? Integer(params[:deductible]) * 100 : @address.state == "FL" ? 50000 : 25000
		  	hurricane = params[:hurricane].presence ? Integer(params[:hurricane]) * 100 : @address.state == "FL" ? 50000 : nil
		  	
		  	query = @address.state == "FL" ? "(deductibles ->> 'all_peril')::integer = #{ deductible } AND (deductibles ->> 'hurricane')::integer = #{ hurricane }" : "(deductibles ->> 'all_peril')::integer = #{ deductible }"
		  	
		  	puts "\n #{ query }"
		  	
		  	@rates["coverage_c"] = @insurable.insurable_rates
		  										 							 .coverage_c
													 							 .activated
													 							 .where(number_insured: insured_count, interval: billing_period)
													 							 .where(query)
		  	
		  	@rates["liability"] = @insurable.insurable_rates
									  										.liability
									  									  .activated
									  										.where(number_insured: insured_count, interval: billing_period)		
		  	
		  	@rates["optional"] = @insurable.insurable_rates
 	  							  									 .optional
  								  									 .activated
								  										 .where(number_insured: insured_count, interval: billing_period)
		  										 		  		      
	      render json: @rates.to_json,
	             status: :ok
	      
		  end
	   
	  end
	end
end
