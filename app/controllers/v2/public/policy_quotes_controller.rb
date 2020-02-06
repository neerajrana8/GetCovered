##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      
      before_action :set_policy_quote
      
      def update
        @application = @policy_quote.policy_application
        if ["estimated", "quoted"].include? @policy_quote.status && 
           @application.policy_type_id == 4
          
          # Blank for now
          if update_policy_quote_params.has_key?(:tiaPremium)
            @quote.policy_premium.update include_special_premium: true  
          end
          
          if update_policy_quote_params.has_key?(:billing_strategy_id) && 
             update_policy_quote_params[:billing_strategy_id] != @application.billing_strategy_id
            @application.update billing_strategy: BillingStrategy.find(update_policy_quote_params[:billing_strategy_id])
            @policy_quote.generate_invoices_for_term(false, true)
          end
          
        end
      end
      
      def accept
	    	unless @policy_quote.nil?
		    	@user = ::User.find(accept_policy_quote_params[:id])
		    	unless @user.nil?
			    	
			    	if @user.attach_payment_source(accept_policy_quote_params[:source])
				    	
				    	@quote_attempt = @policy_quote.accept
							
							render json: {
								:error => @quote_attempt[:success] ? "Policy Accepted" : "Policy Could Not Be Accepted",
								:message => @quote_attempt[:message]
							}, status: @quote_attempt[:success] ? 200 : 500
							
				    else
				    
				    	render json: {
					    	:error => "Payment Source Could not Be Attached",
					    	:message => "An Error has occured with the provided payment method.  Please try again."
				    	}, status: 500
			    	
			    	end
			    else
			    	
			    	render json: {
				    	:error => "Not Found",
				    	:message => "User #{ params[:id] } counld not be found."
			    	}, status: 400			    
			    
			    end
		    else
		    	
		    	render json: {
			    	:error => "Not Found",
			    	:message => "Policy Quote #{ params[:id] } counld not be found."
		    	}, status: 400
		    
		    end  
	    end
      
      private
        
        def set_policy_quote
          @policy_quote = PolicyQuote.find(params[:id])
        end
        
        def update_policy_quote_params
          params.require(:policy_quote).permit( :tiaPremium, :billing_strategy_id )  
        end
      
				def accept_policy_quote_params
					params.require(:user).permit( :id, :source )
				end
        
    end
  end # module Public
end
