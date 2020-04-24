module V2
  module StaffAccount
    class PolicyGroupQuotesController < StaffAccountController
      before_action :set_policy_group_quote, only: %i[accept]

      def accept
        result = @policy_group_quote.accept

        render json: {
          error: result[:success] ? 'Policy Group Accepted' : 'Policy Group Could Not Be Accepted',
          message: result[:message]
        }, status: result[:success] ? 200 : 500
      end

      private

      def set_policy_group_quote
        @policy_group_quote = ::PolicyGroupQuote.find(params[:id])
      end
    end
  end
end
