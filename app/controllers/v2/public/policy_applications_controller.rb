##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb
require 'securerandom'

module V2
  module Public
    class PolicyApplicationsController < PublicController

      before_action :set_policy_application, only: %i[update show rent_guarantee_complete]
      before_action :validate_policy_users_params, only: %i[create update]

      def show
        if %w[started in_progress
              abandoned more_required].include?(@policy_application.status)

        else

          render json:   standard_error(:policy_application_not_found, 'Policy Application is not found or no longer available'),
                 status: 404
        end
      end

      def new
        selected_policy_type = params[:policy_type].blank? ? 'residential' : params[:policy_type]

        if valid_policy_types.include?(selected_policy_type)
          policy_type = PolicyType.find_by_slug(selected_policy_type)

          if selected_policy_type == "residential"
            agency_id    = new_residential_params[:agency_id].to_i
            account_id   = new_residential_params[:account_id].to_i
            insurable_id = ((new_residential_params[:policy_insurables_attributes] || []).first || { id: nil })[:id]
            insurable    = Insurable.where(id: insurable_id).take
            if insurable.nil?
              render json:   { error: "Unit not found" },
                     status: :unprocessable_entity
              return
            end
            # MOOSE WARNING: eventually, use account_id/agency_id to determine which to select when there are multiple
            cip        = insurable.carrier_insurable_profiles.where(carrier_id: policy_type.carrier_policy_types.map{|cpt| cpt.carrier_id }).order("created_at ASC").take
            carrier_id = cip&.carrier_id
            if carrier_id.nil?
              render json:   { error: "Invalid unit" },
                     status: :unprocessable_entity
              return
            end
          elsif selected_policy_type == "commercial"
            carrier_id = 3
          elsif selected_policy_type == 'rent-guarantee'
            carrier_id = 4
          end

          carrier = Carrier.find(carrier_id)

          @application = PolicyApplication.new(policy_type: policy_type, carrier: carrier, agency_id: agency_id, account_id: account_id)
          @application.build_from_carrier_policy_type
          @primary_user = ::User.new
          @application.users << @primary_user

        else
          render json:   standard_error(:invalid_policy_type, 'Invalid policy type'),
                 status: :unprocessable_entity
        end
      end

      def create
        case params[:policy_application][:policy_type_id]
        when 1
          create_residential
        when 4
          create_commercial
        when 5
          create_rental_guarantee
        else
          render json: standard_error(:invalid_policy_type, 'Invalid policy type'), status: 422
        end
      end

      def rent_guarantee_complete
        PolicyApplications::RentGuaranteeMailer.with(policy_application: @policy_application).invite_to_pay.deliver_later
        render json: { message: 'Instructions were sent' }
      end

      def create_policy_users
        error_status = []

        create_policy_users_params[:policy_users_attributes].each_with_index do |policy_user, index|
          if ::User.where(email: policy_user[:user_attributes][:email]).exists?
            @user = ::User.find_by_email(policy_user[:user_attributes][:email])

            if @user.invitation_accepted_at? == false
              @user.update(policy_user[:user_attributes])
              @user.profile.update(policy_user[:user_attributes][:profile_attributes])
            end

            if index == 0
              if @user.invitation_accepted_at? == false
                @application.users << @user
                error_status << false
              else
                render(json: standard_error(
                               :auth_error,
                               'A User has already signed up with this email address.  Please log in to complete your application'
                             ).to_json, status: 401) && return
              end
            else
              @application.users << @user
            end

            if policy_user[:user_attributes][:address_attributes]
              if @user.address.nil?
                @user.create_address(
                  street_number: policy_user[:user_attributes][:address_attributes][:street_number],
                  street_name:   policy_user[:user_attributes][:address_attributes][:street_name],
                  street_two:    policy_user[:user_attributes][:address_attributes][:street_two],
                  city:          policy_user[:user_attributes][:address_attributes][:city],
                  state:         policy_user[:user_attributes][:address_attributes][:state],
                  country:       policy_user[:user_attributes][:address_attributes][:country],
                  county:        policy_user[:user_attributes][:address_attributes][:county],
                  zip_code:      policy_user[:user_attributes][:address_attributes][:zip_code]
                )
              else

                tmp_full = Address.new(policy_user[:user_attributes][:address_attributes]).set_full_searchable

                if @user.address.full_searchable != tmp_full
                  render(json: {
                    error: :address_mismatch,
                    message: 'The mailing address associated with this email is different than the one supplied in the recent request.  To change your address please log in'
                  }.to_json, status: 401) and return
                end
              end
            end
          else
            secure_tmp_password = SecureRandom.base64(12)
            policy_user_params  = {
              spouse:          policy_user[:spouse] || false,
              user_attributes: {
                email:                 policy_user[:user_attributes][:email],
                password: secure_tmp_password,
                password_confirmation: secure_tmp_password,
                profile_attributes:    {
                  first_name:    policy_user[:user_attributes][:profile_attributes][:first_name],
                  last_name:  policy_user[:user_attributes][:profile_attributes][:last_name],
                  job_title:  policy_user[:user_attributes][:profile_attributes][:job_title],
                  contact_phone: policy_user[:user_attributes][:profile_attributes][:contact_phone],
                  birth_date:    policy_user[:user_attributes][:profile_attributes][:birth_date],
                  salutation:    policy_user[:user_attributes][:profile_attributes][:salutation],
                  gender:        policy_user[:user_attributes][:profile_attributes][:gender]
                }
              }
            }
            if policy_user[:user_attributes][:address_attributes]
              policy_user_params[:user_attributes][:address_attributes] = {
                street_number: policy_user[:user_attributes][:address_attributes][:street_number],
                street_name:   policy_user[:user_attributes][:address_attributes][:street_name],
                street_two:    policy_user[:user_attributes][:address_attributes][:street_two],
                city:          policy_user[:user_attributes][:address_attributes][:city],
                state:         policy_user[:user_attributes][:address_attributes][:state],
                country:       policy_user[:user_attributes][:address_attributes][:country],
                county:        policy_user[:user_attributes][:address_attributes][:county],
                zip_code:      policy_user[:user_attributes][:address_attributes][:zip_code]
              }
            end

            policy_user = @application.policy_users.create(policy_user_params)
            if policy_user.errors.any?
              render(
                json: standard_error(:user_creation_error, "User can't be created", policy_user.errors.full_messages),
                status: 422
              ) and return
            end
          end
        end

        error_status.include?(true) ? false : true
      end

      def validate_policy_users_params
        users_emails =
          create_policy_users_params[:policy_users_attributes].
            map { |policy_user| policy_user[:user_attributes][:email] }.
            compact

        if users_emails.count > users_emails.uniq.count
          render(
            json:   {
                    error:   :bad_arguments,
                    message: "You can't use the same emails for policy applicants"
                  }.to_json,
            status: 401
          ) and return
        end
      end

      def create_rental_guarantee

        @application        = PolicyApplication.new(create_rental_guarantee_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = Agency.where(master_agency: true).take if @application.agency.nil?

        @application.billing_strategy = BillingStrategy.where(agency:      @application.agency,
                                                              policy_type: @application.policy_type).take

        if @application.save
          if create_policy_users
            if @application.update(status: 'in_progress')
              LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @application)
              render 'v2/public/policy_applications/show'
            else
              render json: standard_error(:policy_application_update_error, nil, @application.errors),
                     status: 422
            end
          end
        else
          # Rental Guarantee Application Save Error
          render json: standard_error(:policy_application_update_error, nil, @application.errors),
                 status: 422
        end
      end

      def create_commercial

        @application        = PolicyApplication.new(create_commercial_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = Agency.where(master_agency: true).take if @application.agency.nil?

        @application.billing_strategy = BillingStrategy.where(agency:      @application.agency,
                                                              policy_type: @application.policy_type,
                                                              carrier: @application.carrier,
                                                              title:       'Annually').take

        if @application.save
          if create_policy_users
            if @application.update(status: 'complete')
              quote_attempt = @application.crum_quote

              if quote_attempt[:success] == true

                @application.primary_user.set_stripe_id

                @quote = @application.policy_quotes.last
                @quote.generate_invoices_for_term
                @premium = @quote.policy_premium

                response = {
                  id:                 @application.id,
                  quote: {
                    id:      @quote.id,
                    status: @quote.status,
                    premium: @premium
                  },
                  invoices: @quote.invoices.order("due_date ASC"),
                  user:     {
                    id:        @application.primary_user.id,
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
                render json:   standard_error(:quote_failed, quote_attempt[:message]),
                       status: 422
              end
            else
              render json:   standard_error(:policy_application_update_error, nil, @application.errors),
                     status: 422
            end
          end
        else
          # Commercial Application Save Error
          render json:   standard_error(:policy_application_save_error, nil, @application.errors),
                 status: 422

        end
      end

      def create_residential
        @application = PolicyApplication.new(create_residential_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)

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

        if @application.agency.nil? && @application.account.nil?
          @application.agency = Agency.where(master_agency: true).take
        elsif @application.agency.nil?
          @application.agency = @application.account.agency
        end

        if @application.save
          if create_policy_users
            if @application.update status: 'complete'

              # if application.status updated to complete
              @application.estimate()
              @quote = @application.policy_quotes.order('created_at DESC').limit(1).first
              if @application.status != "quote_failed" || @application.status != "quoted"
                # if application quote success or failure
                @application.quote(@quote.id)
                @application.reload
                @quote.reload

                if @quote.status == "quoted"

                  @application.primary_user.set_stripe_id

                  render json:  {
                                 id:       @application.id,
                                 quote: {
                                   id:      @quote.id,
                                   status: @quote.status,
                                   premium: @quote.policy_premium
                                 },
                                 invoices: @quote.invoices.order('due_date ASC'),
                                 user:     {
                                   id:        @application.primary_user.id,
                                   stripe_id: @application.primary_user.stripe_id
                                 }
                               }.merge(@application.carrier_id != 5 ? {} : {
                                 'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                                 'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                                 'installment_total' => @quote.carrier_payment_data['installment_total']
                               }).to_json, status: 200

                else
                  render json: standard_error(:quote_failed, 'Quote could not be processed at this time'),
                         status: 500
                end
              else
                render json: standard_error(:policy_application_unavailable, 'Application cannot be quoted at this time'),
                       status: 400
              end
            else
              render json: standard_error(:policy_application_save_error, nil, @application.errors),
                     status: 422
            end
          end
        else
          render json: standard_error(:policy_application_save_error, nil, @application.errors),
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
          render json: standard_error(:invalid_policy_type, 'Invalid policy type'), status: 422
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
            if @policy_application.status != "quote_failed" || @policy_application.status != "quoted"
              # if application quote success or failure
              @policy_application.quote(@quote.id)
              @policy_application.reload
              @quote.reload

              if @quote.status == "quoted"

                render json:                    {
                               id:       @policy_application.id,
                               quote: {
                                 id:      @quote.id,
                                 status: @quote.status,
                                 premium: @quote.policy_premium
                               },
                               invoices: @quote.invoices.order('due_date ASC'),
                               user:     {
                                 id:        @policy_application.primary_user().id,
                                 stripe_id: @policy_application.primary_user().stripe_id
                               }
                             }.merge(@application.carrier_id != 5 ? {} : {
                               'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                               'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                               'installment_total' => @quote.carrier_payment_data['installment_total']
                             }).to_json, status: 200

              else
                render json: standard_error(:quote_failed, 'Quote could not be processed at this time'),
                       status: 500
              end
            else
              render json: standard_error(:policy_application_unavailable, 'Application cannot be quoted at this time'),
                     status: 400
            end
          else
            render json: standard_error(:policy_application_update_error, nil, @policy_application.errors),
                   status: 422
          end
        end
      end

      def update_rental_guarantee
        @policy_application = PolicyApplication.find(params[:id])

        if @policy_application.policy_type.title == 'Rent Guarantee'
          if update_residential_params[:effective_date].present?
            @policy_application.expiration_date = update_residential_params[:effective_date].to_date&.send(:+, 1.year)
          end
          if @policy_application.update(update_rental_guarantee_params) &&
            update_policy_user(@policy_application) &&
            @policy_application.update(status: 'complete')

            quote_attempt = @policy_application.pensio_quote

            if quote_attempt[:success] == true

              @policy_application.primary_user.set_stripe_id

              @quote         = @policy_application.policy_quotes.last
              invoice_errors = @quote.generate_invoices_for_term
              @premium       = @quote.policy_premium

              response = {
                id:             @policy_application.id,
                quote: {
                  id:      @quote.id,
                  status: @quote.status,
                  premium: @premium
                },
                invoice_errors: invoice_errors,
                invoices:       @quote.invoices,
                user:           {
                  id:        @policy_application.primary_user.id,
                  stripe_id: @policy_application.primary_user.stripe_id
                }
              }

              render json: response.to_json, status: 200

            else
              render json: standard_error(:quote_attempt_failed, quote_attempt[:message]),
                     status: 422
            end

          else
            render json:   standard_error(:policy_application_update_error, nil, @policy_application.errors),
                   status: 422
          end
        end
      end

      def get_coverage_options
        @msi_id                                  = 5
        @residential_community_insurable_type_id = 1
        @residential_unit_insurable_type_id      = 4
        @ho4_policy_type_id                      = 1
        # grab params and validate 'em
        inputs = get_coverage_options_params
        if inputs[:insurable_id].nil?
          render json:   { error: "insurable_id cannot be blank" },
                 status: :unprocessable_entity
          return
        end
        unless inputs[:coverage_selections].nil?
          if inputs[:coverage_selections].class != ::Array
            render json:   { error: "coverage_selections must be an array of coverage selections" },
                   status: :unprocessable_entity
            return
          else
            broken = inputs[:coverage_selections].select { |cs| cs[:category].blank? || cs[:uid].blank? }
            unless broken.length == 0
              render json:   { error: "all entries of coverage_selections must include a category and uid" },
                     status: :unprocessable_entity
              return
            end
          end
        end
        if inputs[:estimate_premium]
          if inputs[:agency_id].nil?
            render json:   { error: "agency_id cannot be blank" },
                   status: :unprocessable_entity
            return
          end
          if inputs[:effective_date].nil?
            render json:   { error: "effective_date cannot be blank" },
                   status: :unprocessable_entity
            return
          else
            begin
              Date.parse(inputs[:effective_date])
            rescue ArgumentError
              render json:   { error: "effective_date must be a valid date" },
                     status: :unprocessable_entity
              return
            end
          end
          if inputs[:additional_insured].nil?
            render json:   { error: "additional_insured cannot be blank" },
                   status: :unprocessable_entity
            return
          end
          if inputs[:billing_strategy_id].nil?
            render json:   { error: "billing_strategy_id cannot be blank" },
                   status: :unprocessable_entity
            return
          end
        end
        # pull unit from db
        unit = Insurable.where(id: inputs[:insurable_id].to_i).take
        if unit.nil? || unit.insurable_type_id != @residential_unit_insurable_type_id
          render json:   { error: "unit not found" },
                 status: :unprocessable_entity
          return
        end
        # grab community and make sure it's registered with msi
        community = unit.parent_community
        cip       = CarrierInsurableProfile.where(carrier_id: @msi_id, insurable_id: community&.id).take
        if cip.nil? || cip.external_carrier_id.nil?
          render json:   { error: "community not found" },
                 status: :unprocessable_entity
          return
        end
        # grab billing strategy and make sure it's valid
        billing_strategy_code = nil
        billing_strategy      = BillingStrategy.where(carrier_id: @msi_id, agency_id: inputs[:agency_id].to_i, policy_type_id: @ho4_policy_type_id, id: inputs[:billing_strategy_id].to_i).take
        if billing_strategy.nil? && inputs[:estimate_premium]
          render json:   { error: "billing strategy must belong to the correct carrier, agency, and HO4 policy type" },
                 status: :unprocessable_entity
          return
        else
          billing_strategy_code = billing_strategy&.carrier_code
        end
        # get coverage options
        results                    = ::InsurableRateConfiguration.get_coverage_options(
          @msi_id,
          cip,
          [{ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true }] + (
            (inputs[:coverage_selections] || []).map{|cs| { 'category' => cs[:category], 'uid' => cs[:uid].to_s, 'selection' => [ActionController::Parameters, ActiveSupport::HashWithIndifferentAccess, ::Hash].include?(cs[:selection].class) ? (cs[:selection][:data_type] == 'currency' ? (cs[:selection][:value].to_d / 100.to_d) : cs[:selection][:value]) : cs[:selection] } }
          ),
          inputs[:effective_date] ? Date.parse(inputs[:effective_date]) : nil,
          inputs[:additional_insured].to_i,
          billing_strategy_code,
          perform_estimate: inputs[:estimate_premium] ? true : false,
          eventable:        unit
        )
        results[:coverage_options] = results[:coverage_options].select{|co| co['uid'] != '1010' && co['uid'] != 1010 }.map{|co| co['options'].blank? ? co : co.merge({'options' => co['options'].map{|v| { 'value' => v, 'data_type' => co['uid'].to_s == '3' && v.to_d == 500 ? 'currency' : co['options_format'] } }.map{|h| h['value'] = (h['value'].to_d * 100).to_i if h['data_type'] == 'currency'; h }}) }
        #results[:coverage_options] = results[:coverage_options].sort_by { |co| co["title"] }.group_by do |co|
        #  if co["category"] == "coverage"
        #    next co["title"].start_with?("Coverage") ? "base_coverages" : "optional_coverages"
        #  else
        #    next "deductibles"
        #  end
        #end
        # done
        render json:   results.select{|k, v| k != :errors }.merge(results[:errors] ? { estimated_premium_errors: [results[:errors][:external]].flatten } : {}),
               status: 200
      end

      private

      # Only for fixing the issue with not saving address on the rent guarantee form
      def update_policy_user(policy_application)
        user = policy_application.primary_user

        policy_user_params = create_policy_users_params[:policy_users_attributes].first

        if user.present? && policy_user_params.present?
          user.update(policy_user_params[:user_attributes])
          return false if user.errors.any?
        end

        true
      end

      def view_path
        super + '/policy_applications'
      end

      def set_policy_application
        puts "SET POLICY APPLICATION RUNNING ID: #{params[:id]}"
        @policy_application = access_model(::PolicyApplication, params[:id])
      end

      def new_residential_params
        params.require(:policy_application)
          .permit(:agency_id, :account_id, :policy_type_id,
                  policy_insurables_attributes: [:id])
      end

      def create_residential_params
        params.require(:policy_application)
          .permit(:effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                  questions:                       [:title, :value, options: []],
                  coverage_selections: [:category, :uid, :selection, selection: [ :data_type, :value ]],
                  extra_settings: [:installment_day],
                  policy_rates_attributes:         [:insurable_rate_id],
                  policy_insurables_attributes:    [:insurable_id])
      end

      def create_commercial_params
        params.require(:policy_application)
          .permit(:effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {},
                  questions:                       [:text, :value, :questionId, options: [], questions: [:text, :value, :questionId, options: []]])
      end

      def create_rental_guarantee_params
        params.require(:policy_application)
          .permit(:effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {})
      end

      def create_policy_users_params
        params.require(:policy_application)
          .permit(policy_users_attributes: [
                                             :primary, :spouse, user_attributes: [
                                                                                   :email, profile_attributes:                        [
                                                                                                                 :first_name, :last_name, :job_title,
                                                                                                                 :contact_phone, :birth_date, :gender,
                                                                                                                 :salutation
                                                                                                               ], address_attributes: [
                                                                                                                                        :city, :country, :county, :id, :latitude, :longitude,
                                                                                                                                        :plus_four, :state, :street_name, :street_number,
                                                                                                                                        :street_two, :timezone, :zip_code
                                                                                                                                      ]
                                                                                 ]
                                           ])
      end

      def update_residential_params
        params.require(:policy_application)
          .permit(policy_rates_attributes:      [:insurable_rate_id],
                  policy_insurables_attributes: [:insurable_id])
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:fields, fields: {})
      end

      def get_coverage_options_params
        params.permit(:insurable_id, :agency_id, :billing_strategy_id,
                      :effective_date, :additional_insured,
                      :estimate_premium,
                      coverage_selections: [:category, :uid, :selection, selection: [ :data_type, :value ]])
      end

      def valid_policy_types
        return ["residential", "commercial", "rent-guarantee"]
      end

    end
  end # module Public
end
