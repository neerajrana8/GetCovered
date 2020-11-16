##
# V2 User PolicyApplications Controller
# File: app/controllers/v2/user/policy_applications_controller.rb

module V2
  module User
    class PolicyApplicationsController < UserController
      before_action :set_policy_application,
                    only: [:show]

      before_action :validate_policy_users_params, only: %i[create update]
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

      def create_rental_guarantee
        @application = PolicyApplication.new(create_rental_guarantee_params)

        @application.agency = Agency.where(master_agency: true).take if @application.agency.nil?

        @application.billing_strategy = BillingStrategy.where(agency: @application.agency,
                                                              policy_type: @application.policy_type).take

        validate_applicant_result =
          PolicyApplications::ValidateApplicantsParameters.run!(
            policy_users_params: create_policy_users_params[:policy_users_attributes],
            current_user_email: current_user.email
          )
        if validate_applicant_result.failure?
          render(json: validate_applicant_result.failure, status: 401) && return
        end

        if @application.save
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes],
              current_user_email: current_user.email
            )

          if update_users_result.success?
            if @application.update(status: 'in_progress')
              render 'v2/public/policy_applications/show'
            else
              render json: @application.errors.to_json,
                     status: 422
            end
          else
            render json: update_users_result.failure, status: 422
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
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes],
              current_user_email: current_user.email
            )
          if update_users_result.success?
            if @application.update(status: 'complete')
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
                  invoices: @quote.invoices.order("due_date ASC"),
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
              render json: update_users_result.failure, status: 422
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
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        if @application.carrier_id == 5
          if !@application.effective_date.nil? && (@application.effective_date >= Time.current.to_date + 90.days || @application.effective_date < Time.current.to_date)
            render json: { "effective_date" => ["must be within the next 90 days"] }.to_json,
                   status: 422
            return
          end
          unless @application.coverage_selections.blank?
            @application.coverage_selections.each do |cs|
              if [ActionController::Parameters, ActiveSupport::HashWithIndifferentAccess, ::Hash].include?(cs['selection'].class)
                cs['selection']['value'] = cs['selection']['value'].to_d / 100.to_d if cs['selection']['data_type'] == 'currency'
                cs['selection'] = cs['selection']['value']
              elsif [ActionController::Parameters, ::Hash].include?(cs[:selection].class)
                cs[:selection][:value] = cs[:selection][:value].to_d / 100.to_d if cs[:selection][:data_type] == 'currency'
                cs[:selection] = cs[:selection][:value]
              end
            end
            @application.coverage_selections.push({ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true })
          end
        end

        if @application.agency.nil? && @application.account.nil?
          @application.agency = Agency.where(master_agency: true).take
        elsif @application.agency.nil?
          @application.agency = @application.account.agency
        end

        if @application.save
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes],
              current_user_email: current_user.email
            )
          if update_users_result.success?
            if @application.update(status: 'complete')
              # if application.status updated to complete
              @application.estimate()
              @quote = @application.policy_quotes.order('created_at DESC').limit(1).first
              if @application.status != 'quote_failed' || @application.status != 'quoted'
                # if application quote success or failure
                @application.quote(@quote.id)
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
                  }.merge(@application.carrier_id != 5 ? {} : {
                    'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                    'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                    'installment_total' => @quote.carrier_payment_data['installment_total']
                  }).to_json, status: 200

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
            render json: update_users_result.failure, status: 422
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

      def update_residential
        @policy_application = PolicyApplication.find(params[:id])

        if @policy_application.policy_type.title == 'Residential'

          @policy_application.policy_rates.destroy_all
          if update_residential_params[:effective_date].present?
            @policy_application.expiration_date = update_residential_params[:effective_date].to_date&.send(:+, 1.year)
          end
          if @policy_application.update(update_residential_params) &&
             @policy_application.update(status: 'complete')

            @policy_application.estimate
            @quote = @policy_application.policy_quotes.order("updated_at DESC").limit(1).first
            if @policy_application.status != 'quote_failed' || @policy_application.status != 'quoted'
              # if application quote success or failure
              @policy_application.quote(@quote.id)
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
                }.merge(@application.carrier_id != 5 ? {} : {
                  'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                  'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                  'installment_total' => @quote.carrier_payment_data['installment_total']
                }).to_json, status: 200

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

        return if @policy_application.policy_type.title != 'Rent Guarantee'

        if @policy_application.update(update_rental_guarantee_params) && @policy_application.update(status: 'complete')
          update_users_result = PolicyApplications::UpdateUsers.run!(
            policy_application: @policy_application,
            policy_users_params: create_policy_users_params[:policy_users_attributes],
            current_user_email: current_user.email
          )
          if update_users_result.success?
            quote_attempt = @policy_application.pensio_quote

            if quote_attempt[:success] == true

              @policy_application.primary_user.set_stripe_id

              @quote         = @policy_application.policy_quotes.last
              invoice_errors = @quote.generate_invoices_for_term
              @premium       = @quote.policy_premium

              response = {
                id: @policy_application.id,
                quote: {
                  id: @quote.id,
                  status: @quote.status,
                  premium: @premium
                },
                invoice_errors: invoice_errors,
                invoices: @quote.invoices,
                user: {
                  id: @policy_application.primary_user.id,
                  stripe_id: @policy_application.primary_user.stripe_id
                }
              }

              render json: response.to_json, status: 200
            else
              render json: standard_error(:quote_attempt_failed, quote_attempt[:message]), status: 422
            end
          else
            render json: update_users_result.failure, status: 422
          end
        else
          render json: @policy_application.errors.to_json, status: 422
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
                  coverage_selections: [:category, :uid, :selection, selection: [ :data_type, :value ]],
                  extra_settings: [:installment_day],
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
                    :spouse, :primary, user_attributes: [
                      :email, profile_attributes: %i[
                        first_name last_name job_title
                        contact_phone birth_date gender salutation
                      ], address_attributes: %i[
                        city country county id latitude longitude
                        plus_four state street_name street_number
                        street_two timezone zip_code
                      ]
                    ]
                  ])
      end

      def update_residential_params
        params.require(:policy_application)
          .permit(:effective_date,
                  :billing_strategy_id, fields: {},
                  policy_rates_attributes: [:insurable_rate_id],
                  policy_insurables_attributes: [:insurable_id])
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:fields, :effective_date, fields: {})
      end

      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
        }
      end

      def validate_policy_users_params
        users_emails =
          create_policy_users_params[:policy_users_attributes].
            map { |policy_user| policy_user[:user_attributes][:email] }.
            compact

        if users_emails.count > users_emails.uniq.count
          render(
            json: {
                    error: :bad_arguments,
                    message: "You can't use the same emails for policy applicants"
                  }.to_json,
            status: 401
          ) && return
        end
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end
end
