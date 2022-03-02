##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class PoliciesController < PublicController
      include PoliciesMethods

      before_action :set_community, only: [:enroll_master_policy]

      def enroll_master_policy
        #TODO: need to remove after testing
        master_policy = @community.policies.where(policy_type_id: 2).take || Policy.last

        @users = access_model(::User).where(email: enrollment_params[:user_attributes].map{|el| el[:email]})
        
        if master_policy.present?
          start_coverage =  master_policy.effective_date
          render json: { message: 'Users not found' }, status: :ok if @users.blank?

          if master_policy.qbe_specialty_issue_coverage(@community, @users, start_coverage)
            render json: { message: 'Insurable was added to master policy coverage' }, status: :ok
          else
            render json: standard_error(
                :insurable_not_added_to_master_policy,
                'Insurable wasn\'t added to master policy coverage'
            ), status: :unprocessable_entity
          end
        else
          render json: standard_error(
              :master_policy_not_founded_for_current_insurable,
              'Master policy wasn\'t found for current insurable'
          ), status: :unprocessable_entity
        end
      end

      private

      def set_community
        @community = Insurable.find(params[:id])
      end

      def enrollment_params
        params.permit(user_attributes: [:email, :first_name, :last_name])
      end

    end

  end # module Public
end

