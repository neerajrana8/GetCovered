module PolicyApplications
  class ValidateApplicantsParameters < ActiveInteraction::Base
    include Dry::Monads[:do, :result]
    include ::StandardErrorMethods

    array :policy_users_params
    string :current_user_email, default: nil

    def execute
      yield validate_primary_count
      yield validate_primary_availability
      Success()
    end

    private

    def validate_primary_count
      primary_users_count = policy_users_params.count { |policy_user_params| policy_user_params[:primary] }
      return Success() if primary_users_count == 1

      Failure(standard_error(:bad_policy_users_arguments, I18n.t('policy_application_contr.validate_applicants.must_have_only_one_primary_user')))
    end

    def validate_primary_availability
      policy_users_params.each do |policy_user_params|
        user = ::User.find_by_email(policy_user_params[:user_attributes][:email])
        if policy_user_params[:primary] && user.present? && user.invitation_accepted_at? && (user.email != current_user_email)
          return Failure(standard_error(:auth_error, I18n.t('policy_application_contr.validate_applicants.already_signup_with_this_email')))
        end
      end
      Success()
    end
  end
end
