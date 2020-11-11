module PolicyApplications
  class UpdateUsers < ActiveInteraction::Base
    object :policy_application
    hash :policy_users_params, strip: false
    string :current_user_email, default: nil

    def execute
      validate_primary_user_params
      remove_policy_users
      policy_users_params.each do |policy_user_params|
        process_user_params(policy_user_params)
      end
    end

    private

    def validate_primary_user_params
      primary_users_count = policy_users_params.count { |policy_user_params| policy_user_params[:primary] }
      if primary_users_count != 1
        standard_error(:bad_policy_users_arguments, 'Parameters must have only one primary user')
      end
    end

    def remove_policy_users
      users_emails = policy_users_params.map { |policy_user_params| policy_user_params[:user_attributes][:email] }
      policy_application.policy_users.includes(:user).each do |policy_user|
        policy_user.destroy if users_emails.exclude?(policy_user.user&.email)
      end
    end

    def process_user_params(policy_user_params)
      policy_user =
        policy_application.
          joins(:users).where(users: { email: policy_user_params[:user_attributes][:email] }).take
      user = User.find_by_email(policy_user_params[:user_attributes][:email])

      if policy_user_params[:primary] && user.present? && user.invitation_accepted_at? && (user.email != current_user_email)
        standard_error(:auth_error, 'A User has already signed up with this email address.  Please log in to complete your application')
      elsif policy_user.present?
        update_policy_user(policy_user, policy_user_params.slice(:primary, :spouse))
        update_user(policy_user.user, policy_user_params[:user_attributes])
      elsif user.present?
        add_policy_user(user, policy_user_params.slice(:primary, :spouse))
        update_user(user, policy_user_params[:user_attributes]) # user became also a policy user
      else
        user = create_user(policy_user_params[:user_attributes])
        add_policy_user(user, policy_user_params.slice(:primary, :spouse))
      end
    end

    def update_policy_user(policy_user, policy_user_params)
      policy_user.update(policy_user_params)
    end

    def add_policy_user(user, policy_user_params)
      PolicyUser.create(policy_user_params.merge(policy_application: policy_application, user: user))
    end

    def update_user(user, user_params)
      return if user.invitation_accepted_at?

      user.update(user_params)
      user.profile.update(user_params[:profile_attributes])

      return if user_params[:address_attributes].blank?

      update_user_address(policy_user, user_params[:address_attributes])
    end

    def create_user(user_params)
      User.create(user_params)
    end

    def update_user_address(user, address_params)
      if user.address.nil?
        user.create_address(address_params)
      else
        user.address.update(address_params)
      end
    end
  end
end
