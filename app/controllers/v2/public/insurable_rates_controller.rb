##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class InsurableRatesController < PublicController
	  
	  	def index
		  	
		  	insured_count = params[:number_insured].presence ? params[:number_insured] : 1
		  	billing_period = params[:billing_period].presence ? params[:billing_period].downcase.sub(/ly/, '') :
		  																											"month"
		  	
		  	@insurable = Insurable.find(params[:id])
		  	@rates = @insurable.insurable_rates
		  										 .activated
		  										 .where(number_insured: insured_count, interval: billing_period)
		  										 .group_by { |r| r.schedule }
		  		      
	      render json: @rates.to_json,
	             status: :ok
	      
		  end
	   
	  end
	end
end
