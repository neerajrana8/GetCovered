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
        unless %w[started in_progress
              abandoned more_required].include?(@policy_application.status)
          render json:   standard_error(:policy_application_not_found, 'Policy Application is not found or no longer available'),
                 status: 404
          return
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
            insurable    = nil
            insurable    = Insurable.where(id: insurable_id, insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS, enabled: true).take
            if insurable.nil?
              render(json: standard_error(:unit_not_found, "Unit not found"), status: :unprocessable_entity) and return
            end
            # determine preferred status
            @preferred = (insurable.parent_community || insurable).preferred_ho4
            # get the carrier_id
            carrier_id = nil
            if @preferred
              # MOOSE WARNING: eventually, use account_id/agency_id to determine which to select when there are multiple
              cip        = insurable.carrier_insurable_profiles.where(carrier_id: policy_type.carrier_policy_types.map{|cpt| cpt.carrier_id }).order("created_at DESC").limit(1).take
              carrier_id = cip&.carrier_id
              if carrier_id.nil?
                render json:   { error: "Invalid unit" },
                       status: :unprocessable_entity
                return
              end
            else
              carrier_id = 5
            end
          elsif selected_policy_type == "commercial"
            carrier_id = 3
          elsif selected_policy_type == 'rent-guarantee'
            carrier_id = 4
          elsif selected_policy_type == 'security-deposit-replacement'
            carrier_id = DepositChoiceService.carrier_id
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
        if request.headers.key?("token-key") && request.headers.key?("token-secret")

          if check_api_access()
            if params[:policy_application][:policy_type_id] == 1 ||
               params[:policy_application][:policy_type_id] == 5
              create_from_external
            else
              render json: standard_error(:invalid_policy_type, 'Invalid policy type'), status: 422
            end
          else
            render json: standard_error(:authentication, 'Invalid Auth Key'), status: 401
          end
        else
          case params[:policy_application][:policy_type_id]
          when 1
            create_residential
          when 4
            create_commercial
          when 5
            create_rental_guarantee
          when 6
            create_security_deposit_replacement
          else
            render json: standard_error(:invalid_policy_type, 'Invalid policy type'), status: 422
          end
        end
      end

      def rent_guarantee_complete
        PolicyApplications::RentGuaranteeMailer.with(policy_application: @policy_application).invite_to_pay.deliver_later
        render json: { message: 'Instructions were sent' }
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

        validate_applicant_result =
          PolicyApplications::ValidateApplicantsParameters.run!(
            policy_users_params: create_policy_users_params[:policy_users_attributes]
          )
        if validate_applicant_result.failure?
          render(json: validate_applicant_result.failure, status: 401) && return
        end

        if @application.save
          if @application.update(status: 'in_progress')
            LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @application)
            render 'v2/public/policy_applications/show'
          else
            render json: standard_error(:policy_application_update_error, nil, @application.errors),
                   status: 422
          end
        else
          # Rental Guarantee Application Save Error
          render json: standard_error(:policy_application_update_error, nil, @application.errors),
                 status: 422
        end
      end

      def create_from_external
        place_holder_date = Time.now + 1.day
        policy_type = params[:policy_application][:policy_type_id]
        init_hash = {
          :agency => @access_token.bearer,
          :policy_type => PolicyType.find(policy_type),
          :carrier => policy_type == 1 ? Carrier.find(5) : Carrier.find(4),
          :account => policy_type == 1 ? Account.first : nil,
          :effective_date => place_holder_date,
          :expiration_date => place_holder_date + 1.year
        }
        if @access_token.bearer_type == 'Agency'
          if @access_token.bearer_id == ::ConfieService.agency_id
            unless params[:mediacode].blank?
              init_hash[:tagging_data] ||= {}
              init_hash[:tagging_data]['confie_mediacode'] = params.require(:mediacode).to_s
            end
          end
        end

        site = Rails.application.credentials[:uri][Rails.env.to_sym][:client]
        program = policy_type == 1 ? "residential" : "rentguarantee"

        @application = PolicyApplication.new(init_hash)
        @application.build_from_carrier_policy_type
        @application.billing_strategy = BillingStrategy.where(agency:      @application.agency,
                                                              policy_type: @application.policy_type,
                                                              carrier: @application.carrier).take
                                                              
        address_string = params["policy_application"]["fields"]["address"]
        @application.resolver_info = { "address_string" => address_string }

        case policy_type
          when 1 # residential
            unit = ::Insurable.get_or_create(address: address_string, unit: true)
            if unit.class == ::Insurable
              @application.insurables << unit
              @application.policy_insurables.first.primary = true
            end
          when 5 # rent guarantee
            params["policy_application"]["fields"].keys.each do |key|
              @application.fields[key] = params["policy_application"]["fields"][key]
            end
        end

        if @application.save
          @redirect_url = "#{ site }/#{program}/#{ @application.id }"
          if create_policy_users
            if @application.update(status: 'in_progress')
              render 'v2/public/policy_applications/show_external'
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
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )
          if update_users_result.success?
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
          else
            render json: update_users_result.failure, status: 422
          end
        else
          # Commercial Application Save Error
          render json:   standard_error(:policy_application_save_error, nil, @application.errors),
                 status: 422

        end
      end

      def create_security_deposit_replacement
        # set up the application
        @application = PolicyApplication.new(create_security_deposit_replacement_params)
        if @application.agency.nil? && @application.account.nil?
          @application.agency = Agency.where(master_agency: true).take
        elsif @application.agency.nil?
          @application.agency = @application.account.agency
        end
        @application.billing_strategy = BillingStrategy.where(carrier_id: DepositChoiceService.carrier_id).take if @application.billing_strategy.nil? # WARNING: there should only be one (annual) right now
        @application.expiration_date = @application.effective_date + 1.year unless @application.effective_date.nil?
        # try to save
        unless @application.save
          render json: standard_error(:policy_application_save_error, nil, @application.errors),
                 status: 422
          return
        end
        # try to quote application
        if create_policy_users
          # update status to complete
          LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @application)
          unless @application.update(status: 'complete')
            render json: standard_error(:policy_application_save_error, nil, @application.errors),
                   status: 422
            return
          end
          # create quote
          @application.estimate()
          @quote = @application.policy_quotes.order('created_at DESC').limit(1).first
          unless @application.status != "quote_failed" || @application.status != "quoted" # MOOSE WARNING: we should really fix this 100% pointless if statement... it's also broken in residential...
            render json: standard_error(:policy_application_unavailable, 'Application cannot be quoted at this time'),
                   status: 400
            return
          end
          @application.quote(@quote.id)
          @application.reload
          @quote.reload
          unless @quote.status == "quoted"
            render json: standard_error(:quote_failed, 'Quote could not be processed at this time'),
                   status: 500
            return
          end
          # return nice stuff
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
                       }.to_json, status: 200
          return
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
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )

          if update_users_result.success?
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
          else
            render json: update_users_result.failure, status: 422
          end
        else
          render json: standard_error(:policy_application_save_error, nil, @application.errors),
                 status: 422
        end
      end

      def update
        case params[:policy_application][:policy_type_id].to_i
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
          # try to update
          @policy_application.assign_attributes(update_residential_params)
          @policy_application.expiration_date = @policy_application.effective_date&.send(:+, 1.year)
          # fix coverage options if needed
          unless @policy_application.coverage_selections.blank?
            @policy_application.coverage_selections.each do |cs|
              if [ActionController::Parameters, ActiveSupport::HashWithIndifferentAccess, ::Hash].include?(cs['selection'].class)
                cs['selection']['value'] = cs['selection']['value'].to_d / 100.to_d if cs['selection']['data_type'] == 'currency'
                cs['selection'] = cs['selection']['value']
              elsif [ActionController::Parameters, ::Hash].include?(cs[:selection].class)
                cs[:selection][:value] = cs[:selection][:value].to_d / 100.to_d if cs[:selection][:data_type] == 'currency'
                cs[:selection] = cs[:selection][:value]
              end
            end
            @policy_application.coverage_selections.push({ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true })
          end
          # fix agency if needed
          if @policy_application.agency.nil? && @policy_application.account.nil?
            @policy_application.agency = Agency.where(master_agency: true).take
          elsif @policy_application.agency.nil?
            @policy_application.agency = @policy_application.account.agency
          end
          # woot woot, try to update users and save
          update_users_result = update_policy_users_params.blank? ? true :
            PolicyApplications::UpdateUsers.run!(
              policy_application: @policy_application,
              policy_users_params: update_policy_users_params[:policy_users_attributes]
            )
          if !(update_users_result == true || update_users_result.sucess?)
            render json: update_users_result.failure,
              status: 422
          else
            if !@policy_application.save
              render json: standard_error(:policy_application_save_error, nil, @policy_application.errors),
                     status: 422
            else
              if @policy_application.update(status: 'complete')

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
        end
      end

      def update_rental_guarantee
        @policy_application = PolicyApplication.find(params[:id])
        if update_residential_params[:effective_date].present?
          @policy_application.expiration_date = update_residential_params[:effective_date].to_date&.send(:+, 1.year)
        end
        if @policy_application.update(update_rental_guarantee_params) && @policy_application.update(status: 'complete')
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @policy_application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )
          if update_users_result.success?
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
            render json: update_users_result.failure, status: 422
          end
        else
          render json:   standard_error(:policy_application_update_error, nil, @policy_application.errors),
                 status: 422
        end
      end

      def get_coverage_options
        case (get_coverage_options_params[:carrier_id] || MsiService.carrier_id).to_i # we set the default to MSI for now since the form doesn't require a carrier_id input yet for this request
          when MsiService.carrier_id
            msi_get_coverage_options
          when DepositChoiceService.carrier_id
            deposit_choice_get_coverage_options
          else
            render json:   { error: "invalid carrier_id/policy_type_id combination #{get_coverage_options_params[:carrier_id] || 'NULL'}/#{get_coverage_options_params[:policy_type_id] || 'NULL'}" },
                   status: :unprocessable_entity
        end
      end

      def deposit_choice_get_coverage_options
        @residential_unit_insurable_type_id = 4
        # validate params
        inputs = deposit_choice_get_coverage_options_params
        if inputs[:insurable_id].nil?
          render json:   { error: "insurable_id cannot be blank" },
                 status: :unprocessable_entity
          return
        end
        if inputs[:effective_date].nil?
          render json:   { error: "effective_date cannot be blank" },
                 status: :unprocessable_entity
          return
        end
        # pull unit from db
        unit = Insurable.where(id: inputs[:insurable_id].to_i).take
        if unit.nil? || unit.insurable_type_id != @residential_unit_insurable_type_id
          render json:   { error: "unit not found" },
                 status: :unprocessable_entity
          return
        end
        # get coverage options
        result = unit.dc_get_rates(Date.parse(inputs[:effective_date]))
        unless result[:success]
          render json:   { error: "There are no security deposit replacement plans available for this property (error code #{result[:event]&.id || 0})" },
                 status: :unprocessable_entity
          return
        end
        render json: { coverage_options: result[:rates] },
               status: 200
      end

      def msi_get_coverage_options
        @msi_id                                  = MsiService.carrier_id
        @residential_community_insurable_type_id = 1
        @residential_unit_insurable_type_id      = 4
        @ho4_policy_type_id                      = 1
        # grab params and validate 'em
        inputs = msi_get_coverage_options_params
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
        # grab community
        community = unit.parent_community
        cip       = CarrierInsurableProfile.where(carrier_id: @msi_id, insurable_id: community&.id).take # possibly nil, for non-preferred
        if community.nil?
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
          cip || unit.primary_address,
          [{ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true }] + (
            (inputs[:coverage_selections] || []).map{|cs| { 'category' => cs[:category], 'uid' => cs[:uid].to_s, 'selection' => [ActionController::Parameters, ActiveSupport::HashWithIndifferentAccess, ::Hash].include?(cs[:selection].class) ? (cs[:selection][:data_type] == 'currency' ? (cs[:selection][:value].to_d / 100.to_d) : cs[:selection][:value]) : cs[:selection] } }
          ),
          inputs[:effective_date] ? Date.parse(inputs[:effective_date]) : nil,
          inputs[:additional_insured].to_i,
          billing_strategy_code,
          perform_estimate: inputs[:estimate_premium] ? true : false,
          eventable:        unit,
          **(cip ? {} : {
            nonpreferred_final_premium_params: {
              number_of_units: inputs[:number_of_units].to_i,
              years_professionally_managed: inputs[:years_professionally_managed].to_i,
              year_built: inputs[:year_built].to_i,
              gated: inputs[:gated].nil? ? nil : inputs[:gated] ? true : false
            }.compact
          })
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

      def check_api_access
        key = request.headers["token-key"]
        secret = request.headers["token-secret"]
        pass = false

        unless key.nil? || secret.nil?
          @access_token = AccessToken.find_by_key(key)
          if !@access_token.nil? &&
            @access_token.check_secret(secret)
            pass = true
          end
        end

        return pass
      end

      def view_path
        super + '/policy_applications'
      end

      def set_policy_application
        puts "SET POLICY APPLICATION RUNNING ID: #{params[:id]}"
        @application = @policy_application = access_model(::PolicyApplication, params[:id])
      end

      def new_residential_params
        params.require(:policy_application)
          .permit(:agency_id, :account_id, :policy_type_id,
                  :address_string, :unit_title, # for non-preferred
                  policy_insurables_attributes: [:id]) # for preferred
      end

      def create_residential_params
        params.require(:policy_application)
          .permit(:effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                  questions:                       [:title, :value, options: []],
                  coverage_selections: [:category, :uid, :selection, selection: [ :data_type, :value ]],
                  extra_settings: [
                    # for MSI
                    :installment_day, :number_of_units, :years_professionally_managed, :year_built, :gated
                  ],
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


      def create_security_deposit_replacement_params
        params.require(:policy_application)
          .permit(:effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                  questions:                       [:title, :value, options: []],
                  coverage_selections: [:bondAmount, :ratedPremium, :processingFee, :totalCost],
                  policy_rates_attributes:         [:insurable_rate_id],
                  policy_insurables_attributes:    [:insurable_id])
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
      
      def update_policy_users_params
        return create_policy_users_params
      end

      def update_residential_params
        return create_residential_params
        params.require(:policy_application)
          .permit(:effective_date, policy_rates_attributes:      [:insurable_rate_id],
                  policy_insurables_attributes: [:insurable_id])
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:effective_date, :fields, fields: {})
      end

      def get_coverage_options_params
        params.permit(:carrier_id, :policy_type_id)
      end

      def deposit_choice_get_coverage_options_params
        params.permit(:insurable_id, :effective_date)
      end

      def msi_get_coverage_options_params
        params.permit(:insurable_id, :agency_id, :billing_strategy_id,
                      :effective_date, :additional_insured,
                      :estimate_premium,
                      :number_of_units, :years_professionally_managed, :year_built, :gated, # nonpreferred stuff
                      coverage_selections: [:category, :uid, :selection, selection: [ :data_type, :value ]])
      end

      def valid_policy_types
        return ["residential", "commercial", "rent-guarantee", "security-deposit-replacement"]
      end

    end
  end # module Public
end
