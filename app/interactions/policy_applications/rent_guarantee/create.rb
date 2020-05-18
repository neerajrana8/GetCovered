module PolicyApplications
  module RentGuarantee
    class Create < ActiveInteraction::Base
      hash :policy_application_params, strip: false
      array :policy_users_params

      def execute
        application = PolicyApplication.new(policy_application_params)
        application.carrier = Carrier.find(4)
        application.policy_type = PolicyType.find_by_slug('rent-guarantee')
        application.agency = policy_application_group.agency
        application.account = policy_application_group.account
        application.billing_strategy = policy_application_group.billing_strategy

        if application.save
          if create_policy_users(application) && application.update(status: 'complete')
            quote_attempt = application.pensio_quote

            unless quote_attempt[:success] == true
              ModelError.create(
                model: application,
                kind: :policy_application_was_not_quoted,
                information: {
                  params: policy_application_params,
                  policy_users_params: policy_users_params,
                  errors: application.errors
                }
              )
            end
          else
            ModelError.create(
              model: application,
              kind: :policy_application_did_not_update_status_to_complete,
              information: {
                params: policy_application_params,
                policy_users_params: policy_users_params,
                errors: application.errors
              }
            )
          end
        elsif policy_application_group
          ModelError.create(
            model: policy_application_group,
            kind: :policy_application_was_not_created,
            information: {
              params: policy_application_params,
              policy_users_params: policy_users_params,
              errors: application.errors
            }
          )
        end
      rescue StandardError => e
        ModelError.create(
          model: policy_application_group,
          kind: :unknown_error,
          information: {
            params: policy_application_params,
            policy_users_params: policy_users_params,
            errors: e.to_s
          }
        )
        Rails.logger.error "[#{self.class.name}] Hey, something was wrong with this interaction #{e.to_s}"
      ensure
        policy_application_group&.update_status
      end

      private

      def policy_application_group
        @policy_application_group ||= policy_application_params[:policy_application_group]
      end

      def create_policy_users(application)
        policy_users_params.each_with_index do |policy_user, _|
          if ::User.where(email: policy_user[:user_attributes][:email]).exists?
            user = ::User.find_by_email(policy_user[:user_attributes][:email])
            application.users << user
          else
            secure_tmp_password = SecureRandom.base64(12)
            policy_user = application.policy_users.create(
              spouse: policy_user[:spouse],
              user_attributes: {
                email: policy_user[:user_attributes][:email],
                password: secure_tmp_password,
                password_confirmation: secure_tmp_password,
                profile_attributes: policy_user[:user_attributes][:profile_attributes],
                address_attributes: policy_user[:user_attributes][:address_attributes]
              }
            )
            if policy_user.errors.any?
              ModelError.create(
                model: application,
                kind: :policy_application_user_was_not_created,
                information: {
                  params: policy_application_params,
                  policy_users_params: policy_users_params,
                  errors: policy_user.errors
                }
              )
              return false
            end
          end
        end
        true
      end
    end
  end
end
