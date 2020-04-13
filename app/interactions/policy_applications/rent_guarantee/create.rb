module PolicyApplications
  module RentGuarantee
    class Create < ActiveInteraction::Base
      hash :policy_application_params, strip: false
      array :policy_users_params
      
      
      def execute
        application = PolicyApplication.new(policy_application_params)
        application.carrier = Carrier.find(4)
        application.policy_type = PolicyType.find_by_slug('rent-guarantee')
        application.agency = Agency.where(master_agency: true).take
        application.billing_strategy = BillingStrategy.where(agency: application.agency, policy_type: application.policy_type).take
        if application.save
          if create_policy_users(application)
            if application.update(status: 'complete')
              application.primary_user().invite! # Waiting clarification from Brandon, maybe it should be deleted
              quote_attempt = application.pensio_quote()
              if quote_attempt[:success] == true
                application
              else
                errors.merge!(application.errors)
              end
            else
              errors.merge!(application.errors)
            end
          end
        else
          errors.merge!(application.errors)
        end
      end

      private

      def policy_application_group
        @policy_application_group ||= policy_application_params[:policy_application_group]
      end

      def create_policy_users(application)
        error_status = []
        policy_users_params.each_with_index do |policy_user, index|
          if ::User.where(email: policy_user[:user_attributes][:email]).exists?
            user = ::User.find_by_email(policy_user[:user_attributes][:email])
            application.users << user
          else
            secure_tmp_password = SecureRandom.base64(12)
            policy_user = application.policy_users.create!(
              spouse: policy_user[:spouse],
              user_attributes: {
                email: policy_user[:user_attributes][:email],
                password: secure_tmp_password,
                password_confirmation: secure_tmp_password,
                profile_attributes: {
                  first_name: policy_user[:user_attributes][:profile_attributes][:first_name],
                  last_name: policy_user[:user_attributes][:profile_attributes][:last_name],
                  job_title: policy_user[:user_attributes][:profile_attributes][:job_title],
                  contact_phone: policy_user[:user_attributes][:profile_attributes][:contact_phone],
                  birth_date: policy_user[:user_attributes][:profile_attributes][:birth_date]
                }
              }
            )
            policy_user.user.invite! if index == 0 # @todo Waiting clarification from Brandon, maybe it should be deleted
          end
        end

        error_status.include?(true) ? false : true
      end
    end
  end
end
