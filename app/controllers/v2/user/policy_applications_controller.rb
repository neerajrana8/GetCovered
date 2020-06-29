##
# V2 User PolicyApplications Controller
# File: app/controllers/v2/user/policy_applications_controller.rb

module V2
  module User
    class PolicyApplicationsController < UserController

      before_action :set_policy_application,
                    only: [:show]

      before_action :set_substrate,
                    only: %i[create index]

      def index
        if params[:short]
          super(:@policy_applications, @substrate)
        else
          super(:@policy_applications, @substrate)
        end
      end

      def show; end

      def create
        case params[:policy_application][:policy_type_id]
        when 1
          create_residential
        when 4
          create_commercial
        when 5
          create_rental_guarantee
        else
          render json: {
            title: 'Policy Type not Recognized',
            message: 'Policy Type is not residential or commercial.  Please select a supported Policy Type'
          }, status: 422
        end
      end

      def create_policy_users
        error_status = []
        params[:policy_application][:policy_users_attributes].each_with_index do |policy_user, index|
          user = ::User.where(email: policy_user[:user_attributes][:email]).take
          if user.present? && user == current_user
            user.update(policy_user[:user_attributes])
            user.profile.update(policy_user[:user_attributes][:profile_attributes])

            @application.users << user
          elsif user.present?
            if index.zero?
              if user.invitation_accepted_at? == false
                @application.users << user
                error_status << false
              else
                render json: {
                               error: 'User Account Exists',
                               message: 'A User has already signed up with this email address.  Please log in to complete your application'
                             }.to_json,
                       status: 401
                error_status << true
                break
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
                  birth_date: policy_user[:user_attributes][:profile_attributes][:birth_date],
                  salutation: policy_user[:user_attributes][:profile_attributes][:salutation],
                  gender: policy_user[:user_attributes][:profile_attributes][:gender]
                }
              }
            )

            policy_user.user.invite! if index.zero?
          end
        end
        error_status.include?(true) ? false : true
      end

      def create_rental_guarantee

        @application = PolicyApplication.new(create_rental_guarantee_params)

        @application.agency = Agency.where(master_agency: true).take if @application.agency.nil?

        @application.billing_strategy = BillingStrategy.where(agency: @application.agency,
                                                              policy_type: @application.policy_type).take

        if @application.save
          if create_policy_users && @application.update(status: 'in_progress')
            render 'v2/public/policy_applications/show'
          else
            render json: @application.errors.to_json,
                   status: 422
          end
        else
          # Rental Guarantee Application Save Error
          render json: @application.errors.to_json,
                 status: 422
        end
      end

      def create_commercial

        @application = PolicyApplication.new(create_commercial_params)
        @application.agency = Agency.where(master_agency: true).take

        @application.billing_strategy = BillingStrategy.where(agency: @application.agency,
                                                              policy_type: @application.policy_type,
                                                              title: 'Annually').take

        if @application.save
          if create_policy_users && @application.update(status: 'complete')
            # Commercial Application Saved

            quote_attempt = @application.crum_quote

            if quote_attempt[:success] == true

              @application.primary_user.set_stripe_id

              @quote = @application.policy_quotes.last
              @quote.generate_invoices_for_term
              @premium = @quote.policy_premium

              response = {
                id: @application.id,
                quote: {
                  id: @quote.id,
                  status: @quote.status,
                  premium: @premium
                },
                invoices: @quote.invoices,
                user: {
                  id: @application.primary_user.id,
                  stripe_id: @application.primary_user.stripe_id
                },
                billing_strategies: []
              }

              if @premium.base >= 500_000
                BillingStrategy.where(agency: @application.agency_id, policy_type: @application.policy_type).each do |bs|
                  response[:billing_strategies] << { id: bs.id, title: bs.title }
                end
              end

              render json: response.to_json, status: 200

            else
              render json: { error: 'Quote Failed', message: quote_attempt[:message] },
                     status: 422
            end
          else
            render json: @application.errors.to_json,
                   status: 422
          end
        else

          # Commercial Application Save Error
          render json: @application.errors.to_json,
                 status: 422

        end
      end

      def create_residential

        @application = PolicyApplication.new(create_residential_params)

        if @application.agency.nil? &&
           @application.account.nil?

          @application.agency = Agency.where(master_agency: true).take
        elsif @application.agency.nil?

          @application.agency = @application.account.agency
        end

        if @application.save
          if create_policy_users && @application.update(status: 'complete')

            # if application.status updated to complete
            @application.qbe_estimate
            @quote = @application.policy_quotes.last
            if @application.status != 'quote_failed' || @application.status != 'quoted'
              # if application quote success or failure
              @application.qbe_quote(@quote.id)
              @application.reload
              @quote.reload

              if @quote.status == 'quoted'

                @application.primary_user.set_stripe_id

                render json: {
                  id: @application.id,
                  quote: {
                    id: @quote.id,
                    status: @quote.status,
                    premium: @quote.policy_premium
                  },
                  invoices: @quote.invoices.order('due_date ASC'),
                  user: {
                    id: @application.primary_user.id,
                    stripe_id: @application.primary_user.stripe_id
                  }
                }.to_json, status: 200

              else
                render json: { error: 'Quote Failed', message: 'Quote could not be processed at this time' },
                       status: 500
              end
            else
              render json: { error: 'Application Unavailable', message: 'Application cannot be quoted at this time' },
                     status: 400
            end

          else
            render json: @application.errors.to_json,
                   status: 422
          end
        else
          render json: @application.errors.to_json,
                 status: 422
        end
      end

      def update
        case params[:policy_application][:policy_type_id]
        when 1
          update_residential
        when 5
          update_rental_guarantee
        else
          render json: {
            title: 'Policy or Guarantee Type Not Recognized',
            message: 'Only Residential Policies and Rental Guaranatees are available for update from this screen'
          }, status: 422
        end
      end

      def update
        @policy_application = PolicyApplication.find(params[:id])

        if @policy_application.policy_type.title == 'Residential'

          @policy_application.policy_rates.destroy_all

          if @policy_application.update(update_params) &&
             @policy_application.update(status: 'complete')

            @policy_application.qbe_estimate
            @quote = @policy_application.policy_quotes.last
            if @policy_application.status != 'quote_failed' || @policy_application.status != 'quoted'
              # if application quote success or failure
              @policy_application.qbe_quote(@quote.id)
              @policy_application.reload
              @quote.reload

              if @quote.status == 'quoted'

                render json: {
                  id: @policy_application.id,
                  quote: {
                    id: @quote.id,
                    status: @quote.status,
                    premium: @quote.policy_premium
                  },
                  invoices: @quote.invoices.order('due_date ASC'),
                  user: {
                    id: @policy_application.primary_user.id,
                    stripe_id: @policy_application.primary_user.stripe_id
                  }
                }.to_json, status: 200

              else
                render json: { error: 'Quote Failed', message: 'Quote could not be processed at this time' },
                       status: 500
              end
            else
              render json: { error: 'Application Unavailable', message: 'Application cannot be quoted at this time' },
                     status: 400
            end
          else
            render json: @policy_application.errors.to_json,
                   status: 422
          end
        else
          render json: { error: 'Application Unavailable', message: 'Please log in to update a commercial policy application' },
                 status: 401
        end
      end

      def update_rental_guarantee
        @policy_application = PolicyApplication.find(params[:id])

        if @policy_application.policy_type.title == 'Rent Guarantee'

          if @policy_application.update(update_rental_guarantee_params) &&
             @policy_application.update(status: 'complete')

            quote_attempt = @policy_application.pensio_quote

            if quote_attempt[:success] == true

              @policy_application.primary_user.set_stripe_id

              @quote = @policy_application.policy_quotes.last
              results = @quote.generate_invoices_for_term
              @premium = @quote.policy_premium

              response = {
                id: @policy_application.id,
                quote: {
                  id: @policy_application.id,
                  status: @policy_application.status,
                  premium: @premium
                },
                invoices: @quote.invoices,
                user: {
                  id: @policy_application.primary_user.id,
                  stripe_id: @policy_application.primary_user.stripe_id
                }
              }

              render json: response.to_json, status: 200

            else
              render json: { error: 'Quote Failed', message: quote_attempt[:message] },
                     status: 422
            end

          else
            render json: @policy_application.errors.to_json,
                   status: 422
          end
         end
      end

      private

      def view_path
        super + '/policy_applications'
      end

      def create_allowed?
        true
      end

      def set_policy_application
        @policy_application = access_model(::PolicyApplication, params[:id])
      end

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::PolicyApplication)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.policy_applications
        end
      end

      def create_residential_params
        params.require(:policy_application)
          .permit(:effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                                           questions: [:title, :value, options: []],
                                           policy_rates_attributes: [:insurable_rate_id],
                                           policy_insurables_attributes: [:insurable_id])
      end

      def create_commercial_params
        params.require(:policy_application)
          .permit(:effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {},
                                           questions: [:text, :value, :questionId, options: [], questions: [:text, :value, :questionId, options: []]])
      end

      def create_rental_guarantee_params
        params.require(:policy_application)
          .permit(:effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {})
      end

      def create_policy_users_params
        params.require(:policy_application)
          .permit(policy_users_attributes: [
                    :spouse, user_attributes: [
                      :email, profile_attributes: %i[
                        first_name last_name job_title
                        contact_phone birth_date gender salutation
                      ]
                    ]
                  ])
      end

      def update_residential_params
        params.require(:policy_application)
          .permit(:effective_date, :expiration_date,
                  :billing_strategy_id, fields: {},
                                        policy_rates_attributes: [:insurable_rate_id],
                                        policy_insurables_attributes: [:insurable_id])
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:fields, fields: {})
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
