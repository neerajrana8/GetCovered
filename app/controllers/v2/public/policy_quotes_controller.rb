##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      
      before_action :set_policy_quote
      
      def update
        @application = @policy_quote.policy_application
        
        if @policy_quote.quoted? && 
           @application.policy_type_id == 4
          
          logger.debug "\nAVAILABLE FOR UPDATE\n".green
          
          # Blank for now
          if update_policy_quote_params.has_key?(:tiaPremium)
            @policy_quote.policy_premium.update include_special_premium: update_policy_quote_params[:tiaPremium]  
          end
          
          if update_policy_quote_params.has_key?(:billing_strategy_id) && 
             update_policy_quote_params[:billing_strategy_id] != @application.billing_strategy_id
            @application.update billing_strategy: BillingStrategy.find(update_policy_quote_params[:billing_strategy_id])
          end
          
          if update_policy_quote_params.has_key?(:tiaPremium) ||
             update_policy_quote_params.has_key?(:billing_strategy_id)
            
            puts "Updating for premium & invoices".green
            
            @policy_quote.policy_premium.reset_premium()
            @policy_quote.generate_invoices_for_term(false, true)
          else
            
            puts "No updates for premium & invoices".red
          end

					response = { 
						quote: { 
							id: @policy_quote.id, 
							status: @policy_quote.status, 
							premium: @policy_quote.policy_premium
						},
						invoices: @policy_quote.invoices,
						user: { 
							id: @policy_quote.policy_application.primary_user().id,
							stripe_id: @policy_quote.policy_application.primary_user().stripe_id
						},
						billing_strategies: []
					}
								
					if @policy_quote.policy_premium.base >= 500000
						BillingStrategy.where(agency: @policy_quote.policy_application.agency_id, policy_type: @policy_quote.policy_application.policy_type).each do |bs|
						  response[:billing_strategies]	<< { id: bs.id, title: bs.title }
            end
					end
									  
					render json: response.to_json, status: 200
        else
					render json: { error: "Quote Unavailable for Update", message: "We are unable to update this quote due to it already being accepted or not meeting the policy type requirements." }, status: 422          
        end
      end
      
      def accept
	    	unless @policy_quote.nil?
		    	@user = ::User.find(accept_policy_quote_params[:id])
		    	unless @user.nil?
						result = @user.attach_payment_source(accept_policy_quote_params[:source])
			    	if result.valid?
				    	@quote_attempt = @policy_quote.accept
				    	@policy_type_identifier = @policy_quote.policy_application.policy_type_id == 5 ? "Rental Guarantee" : "Policy"
							if @quote_attempt[:success]
								::Analytics.track(
									user_id: @user.id,
									event: 'Order Completed',
									properties: { plan: 'Orders' }
								)
							end
							render json: {
								:error => @quote_attempt[:success] ? "#{ @policy_type_identifier } Accepted" : "#{ @policy_type_identifier } Could Not Be Accepted",
								:message => @quote_attempt[:message]
							}, status: @quote_attempt[:success] ? 200 : 500
							
				    else
				    	render json: { error: "Failure", message: result.errors.full_messages.join(' and ') }.to_json, status: 422
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
