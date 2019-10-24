# V2 Stripe Controller
# file: app/controllers/v1/stripe_controller.rb

module V2
  class StripeController < V2Controller
  
    # Blank for now...
    
    private
    
      def log_event(success = false, model = nil, method = nil)
        #unless model.nil? || method.nil?
        #  
        #  status_color = success == false ? :red : :green
        #  status_message = success == false ? "ERROR" : "SUCCESS"
        #  
        #  logger.debug "#{ "[".yellow } #{ "Stripe Webhook Service".blue } #{ "]".yellow }#{ "[".yellow } #{ model.blue } #{ "]".yellow }#{ "[".yellow } #{ status_message.colorize(status_color) } #{ "]".yellow }: #{ method.blue }"
        #    
        #end
      end
  end
end
