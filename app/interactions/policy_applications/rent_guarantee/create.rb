module PolicyApplications
  module RentGuarantee
    class Create < ActiveInteraction::Base
      hash :policy_application_params
      hash :policy_users_params
      
      
      def execute
        application = PolicyApplication.new(policy_application_params)
        application.agency = Agency.where(master_agency: true).take
        application.billing_strategy = BillingStrategy.where(agency: application.agency,
                                                              policy_type: application.policy_type).take

        if application.save
          if create_policy_users()
            if application.update(status: 'complete')
              # Commercial Application Saved

              application.primary_user().invite!
              quote_attempt = application.pensio_quote()

              if quote_attempt[:success] == true

                application.primary_user().set_stripe_id()

                quote = application.policy_quotes.last
                quote.generate_invoices_for_term()
                premium = quote.policy_premium

                response = {
                  id: application.id,
                  quote: {
                    id: quote.id,
                    status: quote.status,
                    premium: premium
                  },
                  invoices: quote.invoices,
                  user: {
                    id: application.primary_user().id,
                    stripe_id: application.primary_user().stripe_id
                  }
                }

                render json: response.to_json, status: 200

              else
                render json: { error: "Quote Failed", message: quote_attempt[:message] },
                       status: 422
              end
            else
              render json: application.errors.to_json,
                     status: 422
            end
          end
        else
          # Rental Guarantee Application Save Error
          render json: application.errors.to_json,
                 status: 422
        end
      end

      private

      def create_policy_users
        error_status = []
        policy_users_params.each_with_index do |policy_user, index|
          if ::User.where(email: policy_user[:user_attributes][:email]).exists?
            @user = ::User.find_by_email(policy_user[:user_attributes][:email])
            if index == 0
              if @user.invitation_accepted_at? == false
                @application.users << @user
                error_status << false
              else
                render json: {
                  error: "User Account Exists",
                  message: "A User has already signed up with this email address.  Please log in to complete your application"
                }.to_json,
                       status: 401
                error_status << true
              end
            else
              @application.users << @user
            end
          else
            secure_tmp_password = SecureRandom.base64(12)
            policy_user = @application.policy_users.create!(
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
            policy_user.user.invite! if index == 0
          end
        end

        error_status.include?(true) ? false : true
      end
    end
  end
end
