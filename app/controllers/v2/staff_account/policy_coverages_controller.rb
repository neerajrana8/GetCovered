##
# V2 StaffAccount Policies Controller
# File: app/controllers/v2/staff_account/policy_coverages_controller.rb

module V2
  module StaffAccount
    class PolicyCoveragesController < StaffAccountController
      
      before_action :set_policy_coverage, only: [:update]            
      
      def update
        if update_allowed?
          if @policy_coverage.update(update_params)
            render :show, status: :ok
          else
            render json: @policy_coverage.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
          status: :unauthorized
        end
      end
      
      
      private
      
      def view_path
        super + "/policy_coverages"
      end
      
      def update_allowed?
        @policy_coverage&.policy&.account == current_staff.organizable
      end
      
      def set_policy_coverage
        @policy_coverage = PolicyCoverage.find(params[:id])
      end
      
      def update_params
        params.require(:policy_coverage).permit(
          :designation, :limit, :title, :deductible
        )
      end
    end
  end # module StaffAccount
end