module PolicyApplications
  class UpdateUsers < ActiveInteraction::Base
    include Dry::Monads[:do, :result]
    include ::StandardErrorMethods

    object :policy_application
    array :policy_users_params
    string :current_user_email, default: nil

    def execute
      yield validate_primary_user_params
      yield remove_policy_users
      policy_users_params.each do |policy_user_params|
        yield process_user_params(policy_user_params)
      end
      Success()
    end

    private

    def validate_primary_user_params
      primary_users_count = policy_users_params.count { |policy_user_params| policy_user_params[:primary] }
      return Success() if primary_users_count == 1

      Failure(standard_error(:bad_policy_users_arguments, 'Parameters must have only one primary user'))
    end

    def remove_policy_users
      users_emails = policy_users_params.map { |policy_user_params| policy_user_params[:user_attributes][:email] }

      policy_application.policy_users.includes(:user).each do |policy_user|
        policy_user.destroy if users_emails.exclude?(policy_user.user&.email)
        if policy_user.errors.any?
          return Failure(standard_error(:unbound_policy_user_fail, 'Cant unbound the policy user', policy_user.errors.full_messages))
        end
      end

      Success()
    end

    def process_user_params(policy_user_params)
      policy_user =
        policy_application.
          policy_users.
          joins(:user).
          where(users: { email: policy_user_params[:user_attributes][:email] }).take

      # will be the same as the +policy_user.user+ if the +policy_user+ present
      user = User.find_by_email(policy_user_params[:user_attributes][:email])
      if policy_user_params[:primary] && user.present? && user.invitation_accepted_at? && (user.email != current_user_email)
        return Failure(standard_error(:auth_error, 'A User has already signed up with this email address.  Please log in to complete your application'))
      elsif policy_user.present? # user exists and already added as a policy user
        yield update_policy_user(policy_user, policy_user_params.slice(:primary, :spouse))
        yield update_user(user, policy_user_params[:user_attributes])
        yield update_user_address(user, policy_user_params[:user_attributes][:address_attributes])
      elsif user.present? # user exists but not added as a policy user
        yield add_policy_user(user, policy_user_params.slice(:primary, :spouse))
        yield update_user(user, policy_user_params[:user_attributes])
        yield update_user_address(user, policy_user_params[:user_attributes][:address_attributes])
      else # user does not exist
        user = yield create_user(policy_user_params[:user_attributes])
        yield add_policy_user(user, policy_user_params.slice(:primary, :spouse))
      end
      Success()
    end

    def update_policy_user(policy_user, policy_user_params)
      policy_user.update(policy_user_params)
      if policy_user.errors.empty?
        Success(policy_user)
      else
        Failure(standard_error(:policy_user_updating_failed, 'Cant update the policy user', policy_user.errors.full_messages))
      end
    end

    def add_policy_user(user, policy_user_params)
      policy_user = PolicyUser.create(policy_user_params.merge(policy_application: policy_application, user: user))
      if policy_user.errors.empty?
        Success(policy_user)
      else
        Failure(standard_error(:policy_user_adding_failed, 'Cant add the policy user', policy_user.errors.full_messages))
      end
    end

    def update_user(user, user_params)
      return Success(user) if user.invitation_accepted_at? # skip if a user is active

      user.update(user_params)
      user.profile.update(user_params[:profile_attributes])
      if user.errors.empty?
        Success(user)
      else
        Failure(standard_error(:user_updation_failed, 'Cant update user', user.errors.full_messages))
      end
    end

    def create_user(user_params)
      secure_tmp_password = SecureRandom.base64(12)
      user = User.create(user_params.merge(password: secure_tmp_password, password_confirmation: secure_tmp_password))
      if user.errors.empty?
        Success(user)
      else
        Failure(standard_error(:user_creation_failed, 'Cant create user', user.errors.full_messages))
      end
    end

    def update_user_address(user, address_params)
      address = user.address
      address =
        if address.nil?
          user.create_address(address_params)
        else
          address.update(address_params)
          address
        end
      if address.errors.empty?
        Success(address)
      else
        Failure(standard_error(:user_address_update_failed, 'Cant update address', address.errors.full_messages))
      end
    end
  end
end
