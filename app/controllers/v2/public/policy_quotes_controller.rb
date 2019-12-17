##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      
      before_action :set_policy_quote
      
      def accept
	    	unless @policy_quote.nil?
		    	@user = User.find(accept_policy_quote_params[:id])
		    	unless @user.nil?
			    	
			    	if @user.update accept_policy_quote_params
				    	if @policy_quote.accept
					    	render json: {
						    	:title => "Policy Accepted",
						    	:message => "Policy #{ @policy_quote.policy.number }, has been accepted.  Please check your email for more information."
					    	}, status: 200
							else
					    	render json: {
						    	:error => "Policy Could Not Be Accepted",
						    	:message => "An Error has occured issuing your policy.  Please contact support@getcoveredinsurance.com."
					    	}, status: 200
							end
				    else
			    		logger.degug @user.errors
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
      
				def accept_policy_quote_params
					params.require(:user).permit( :id, 
													payment_profiles_attributes: [ :id, :source_id ])
				end
        
    end
  end # module Public
end
