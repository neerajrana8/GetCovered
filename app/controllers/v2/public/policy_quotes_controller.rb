##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      
      before_action :set_policy_quote,
        only: [:update, :show]
      
      def show
      end
      
      def update
        if update_allowed?
          if @policy_quote.update(update_params)
            render :show,
              status: :ok
          else
            render json: @policy_quote.errors,
              status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/policy_quotes"
        end
        
        def update_allowed?
          true
        end
        
        def set_policy_quote
          @policy_quote = access_model(::PolicyQuote, params[:id])
        end
        
        def update_params
          return({}) if params[:policy_quote].blank?
          to_return = {}
        end
        
    end
  end # module Public
end
