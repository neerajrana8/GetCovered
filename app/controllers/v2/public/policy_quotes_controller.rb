##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      
      before_action :set_policy_quote
      
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
# 				    	if @quote_attempt[:success]
# 					    	render json: {
# 						    	:title => "Policy Accepted",
# 						    	:message => @quote_attempt[:message]
# 					    	}, status: 200
# 							else
# 					    	render json: {
# 						    	:error => "Policy Could Not Be Accepted",
# 						    	:message => @quote_attempt[:message]
# 					    	}, status: 500
# 							end
				    else
				      logger.debug @user.errors
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
      
				def accept_policy_quote_params
					params.require(:user).permit( :id, :source )
				end
        
    end
  end # module Public
end
