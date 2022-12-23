##
# V2 User PolicyApplications Controller
# File: app/controllers/v2/user/policy_applications_controller.rb

module V2
  module User
    class PolicyApplicationsController < UserController
      before_action :set_policy_application,
                    only: [:show]

      before_action :validate_policy_users_params, only: %i[create update]
      before_action :set_substrate, only: %i[create index]

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
        when 6
          create_security_deposit_replacement
        else
          render json: {
            title: I18n.t('user_policy_application_controller.policy_type_not_recognized'),
            message: I18n.t('user_policy_application_controller.policy_type_is_not_residential_or_commercial')
          }, status: 422
        end
      end

      def create_rental_guarantee
        @application = PolicyApplication.new(create_rental_guarantee_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?
        @application.billing_strategy = BillingStrategy.where(agency: @application.agency, carrier: @application.carrier, policy_type: @application.policy_type).take if @application.billing_strategy.nil?

        validate_applicant_result =
          PolicyApplications::ValidateApplicantsParameters.run!(
            policy_users_params: create_policy_users_params[:policy_users_attributes],
            current_user_email: current_user.email
          )
        if validate_applicant_result.failure?
          render(json: validate_applicant_result.failure, status: 401) && return
        end

        if @application.save
          if @application.update(status: 'in_progress')
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
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?
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
                @premium = @quote.policy_premium
                # generate invoices
                result = @quote.generate_invoices_for_term
                unless result.nil?
                  puts result[:internal]
                  quote.mark_failure(result[:internal])
                  render json: standard_error(:quote_failed, I18n.t(result[:external])),
                         status: 400
                  return
                end

                if @premium.base >= 500_000
                  BillingStrategy.where(agency: @application.agency_id, policy_type: @application.policy_type).each do |bs|
                    @extra_fields ||= { billing_strategies: [] }
                    @extra_fields[:billing_strategies] << { id: bs.id, title: bs.title }
                  end
                end

                render template: 'v2/user/policy_applications/create.json', status: 200

              else
                render json: { error: I18n.t('user_policy_application_controller.quote_failed'), message: quote_attempt[:message] },
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

      def create_security_deposit_replacement
        # set up the application
        @application = PolicyApplication.new(create_security_deposit_replacement_params)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?
        @application.billing_strategy = BillingStrategy.where(carrier_id: DepositChoiceService.carrier_id, agency_id: @application.agency_id).take # WARNING: there should only be one (annual) right now
        @application.expiration_date = @application.effective_date + 1.year unless @application.effective_date.nil?
        # try to save
        unless @application.save
          render json: standard_error(:policy_application_save_error, nil, @application.errors),
                 status: 422
          return
        end
        # try to quote application
        update_users_result =
          PolicyApplications::UpdateUsers.run!(
            policy_application: @application,
            policy_users_params: create_policy_users_params[:policy_users_attributes],
            current_user_email: current_user.email
          )
        if update_users_result.success?
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
          if @application.status == "quote_failed"
            render json: standard_error(:policy_application_unavailable, @application.error_message || I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable')),
                   status: 400
            return
          elsif @application.status == "quoted"
            render json: standard_error(:policy_application_unavailable, I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable')),
                   status: 400
            return
          end
          @application.quote(@quote.id)
          @application.reload
          @quote.reload
          unless @quote.status == "quoted"
            if @application.status == "quote_failed"
              render json: standard_error(:quote_failed, @application.error_message || I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed')),
                     status: 500
              return
            else
              render json: standard_error(:quote_failed, I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed')),
                     status: 500
              return
            end
          end
          # return nice stuff
          render template: 'v2/user/policy_applications/create.json', status: 200
          return
        end
      end

      def create_residential
        @application = PolicyApplication.new(create_residential_params)
        @application.policy_insurables.first.primary = true if @application.policy_insurables.length == 1 # ensure that .primary_insurable actually works before save
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?
        if @application.carrier_id == 5
          if !@application.effective_date.nil? && (@application.effective_date >= Time.current.to_date + 90.days || @application.effective_date < Time.current.to_date)
            render json: { "effective_date" => [I18n.t('user_policy_application_controller.must_be_within_the_next_90_days')] }.to_json,
                   status: 422
            return
          end
        end

        if @application.extra_settings && !@application.extra_settings['additional_interest'].blank?
          if @application.carrier_id == ::MsiService.carrier_id
            error_message = ::MsiService.validate_msi_additional_interest(@application.extra_settings['additional_interest'])
            unless error_message.nil?
              render json: standard_error(:policy_application_save_error, I18n.t(error_message)),
                     status: 400
              return
            end
          elsif @application.carrier_id == ::QbeService.carrier_id
            error_message = ::QbeService.validate_qbe_additional_interest(@application.extra_settings['additional_interest'])
            unless error_message.nil?
              render json: standard_error(:policy_application_save_error, I18n.t(error_message)),
                     status: 400
              return
            end
          end
        end

        if @application.carrier_id == ::QbeService.carrier_id && @application.primary_insurable.account.nil?
          defaults = ::QbeService::FIC_DEFAULTS[@application.primary_insurable.primary_address.state] || ::QbeService::FIC_DEFAULTS[nil]
          missing_fic_info = ::QbeService::FIC_DEFAULT_KEYS.select{|k| !@application.extra_settings&.has_key?(k) && !defaults.has_key?(k) }
          unless missing_fic_info.blank?
            render json: standard_error(:community_information_missing, I18n.t('policy_application_contr.qbe_application.missing_fic_info', missing_list: missing_fic_info.map{|v| I18n.t("policy_application_contr.qbe_application.#{v}") }.join(", "))),
              status: 400
            return
          end
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
                  ::ConfieService.create_confie_lead(@application) if @application.agency_id == ::ConfieService.agency_id
                  @application.primary_user.set_stripe_id

                  @extra_fields = {
                   'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                   'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                   'installment_total' => @quote.carrier_payment_data['installment_total']
                  } if @application.carrier_id == 5
                  render template: 'v2/user/policy_applications/create.json', status: 200

                else
                  render json: { error: I18n.t('user_policy_application_controller.quote_failed'), message: I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed') },
                         status: 500
                end
              else
                render json: { error: I18n.t('user_policy_application_controller.application_unavailable'), message: I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable') },
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
            title: I18n.t('user_policy_application_controller.policy_or_guarantee_not_recognized'),
            message: I18n.t('user_policy_application_controller.only_residential_available_to_update')
          }, status: 422
        end
      end

      def update_residential
        @policy_application = PolicyApplication.find(params[:id])

        if @policy_application.policy_type.title == 'Residential'
          @policy_application.account_id = @policy_application.primary_insurable&.account_id
          # try to update
          @policy_application.assign_attributes(update_residential_params)
          @policy_application.expiration_date = @policy_application.effective_date&.send(:+, 1.year)
          @policy_application.agency = @policy_application.account&.agency || Agency.where(master_agency: true).take if @policy_application.agency.nil?
          @policy_application.account = @policy_application.primary_insurable&.account if @policy_application.account.nil?
          # flee if nonsense is passed for additional interest
          if @policy_application.extra_settings && !@policy_application.extra_settings['additional_interest'].blank?
            if @policy_application.carrier_id == ::MsiService.carrier_id
              error_message = ::MsiService.validate_msi_additional_interest(@policy_application.extra_settings['additional_interest'])
              unless error_message.nil?
                render json: standard_error(:policy_application_save_error, I18n.t(error_message)),
                       status: 400
                return
              end
            elsif @policy_application.carrier_id == ::QbeService.carrier_id
              error_message = ::QbeService.validate_qbe_additional_interest(@policy_application.extra_settings['additional_interest'])
              unless error_message.nil?
                render json: standard_error(:policy_application_save_error, I18n.t(error_message)),
                       status: 400
                return
              end
            end
          end
          # remove duplicate pis
          @policy_application.policy_rates.destroy_all
          @replacement_policy_insurables = nil
          saved_pis = @policy_application.policy_insurables.select{|pi| pi.id }
          @policy_application.policy_insurables = @policy_application.policy_insurables.select{|pi| pi.id || (pi.insurable_id && saved_pis.find{|spi| spi.insurable_id == pi.insurable_id }.nil?) }
          unsaved_pis = @policy_application.policy_insurables.select{|pi| pi.id.nil? }.uniq{|pi| pi.insurable_id }
          unless unsaved_pis.blank?
            unsaved_pis.first.primary = true if unsaved_pis.find{|pi| pi.primary }.nil?
            @replacement_policy_insurables = unsaved_pis
          end
          @policy_application.policy_insurables.first.primary = true if @policy_application.policy_insurables.all?{|pi| !pi.primary }
          # scream if we are missing critical community information
          if @policy_application.carrier_id == ::QbeService.carrier_id && @policy_application.primary_insurable.account.nil?
            defaults = ::QbeService::FIC_DEFAULTS[@policy_application.primary_insurable.primary_address.state] || ::QbeService::FIC_DEFAULTS[nil]
            missing_fic_info = ::QbeService::FIC_DEFAULT_KEYS.select{|k| !@policy_application.extra_settings&.has_key?(k) && !defaults.has_key?(k) }
            unless missing_fic_info.blank?
              render json: standard_error(:community_information_missing, I18n.t('policy_application_contr.qbe_application.missing_fic_info', missing_list: missing_fic_info.map{|v| I18n.t("policy_application_contr.qbe_application.#{v}") }.join(", "))),
                status: 400
              return
            end
          end
          # try to update users
          update_users_result = update_policy_users_params.blank? ? true :
            PolicyApplications::UpdateUsers.run!(
              policy_application: @policy_application,
              policy_users_params: update_policy_users_params[:policy_users_attributes],
              current_user_email: current_user.email
            )
          LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @policy_application)
          if !(update_users_result == true || update_users_result.success?)
            render json: update_users_result.failure,
              status: 422
            return
          end
          # fix policy insurables if necessary
          @policy_insurables_to_restore = nil
          unless @replacement_policy_insurables.blank?
            @policy_insurables_to_restore = @policy_application.policy_insurables.select{|pi| pi.id }
            @policy_application.policy_insurables.clear
            @policy_application.policy_insurables = @replacement_policy_insurables
            @policy_application.account = @policy_application.primary_insurable&.account if update_residential_params[:account_id].nil?
          end
          # try updating policy application
          if !@policy_application.save
            # restore the original policy insurables if we changed anything
            unless @policy_insurables_to_restore.blank?
              @policy_application.policy_insurables.clear
              @policy_insurables_to_restore.update_all(policy_application_id: @policy_application.id)
            end
            # scream at the user
            render json: standard_error(:policy_application_save_error, nil, @policy_application.errors),
                   status: 422
            return

          elsif @policy_application.primary_insurable.nil?
            render json: standard_error(:invalid_address, I18n.t('policy_application_contr.update_residential.invalid_address')),
                   status: 400
            return
          elsif !@policy_application.update(status: 'complete')
            render json: standard_error(:policy_application_update_error, nil, @policy_application.errors),
                   status: 422
            return
          end
          # perform estimate
          @policy_application.estimate
          @quote = @policy_application.policy_quotes.order("updated_at DESC").limit(1).first
          if @policy_application.status == "quote_failed"
            render json: { error: I18n.t('user_policy_application_controller.application_unavailable') + " #{@policy_application.error_message}", message: I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable') },
                   status: 400
            return
          elsif @policy_application.status == "quoted"
            render json: { error: I18n.t('user_policy_application_controller.application_unavailable'), message: I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable') },
                   status: 400
            return
          end
          # create quote
          @policy_application.quote(@quote.id)
          @policy_application.reload
          @quote.reload
          if @policy_application.status == "quote_failed"
            render json: standard_error(:quote_failed, I18n.t('user_policy_application_controller.quote_failed') + " #{@policy_application.error_message}"),
                   status: 500
          elsif @quote.status == "quoted"
            @application = @policy_application
            @extra_fields = {
             'policy_fee' => @quote.carrier_payment_data['policy_fee'],
             'installment_fee' => @quote.carrier_payment_data['installment_fee'],
             'installment_total' => @quote.carrier_payment_data['installment_total']
            } if @application.carrier_id == 5
            render template: 'v2/user/policy_applications/create.json', status: 200
          else
            render json: standard_error(:quote_failed, I18n.t('user_policy_application_controller.quote_failed')),
                   status: 500
          end
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
              @premium       = @quote.policy_premium
              # generate invoices
              result = @quote.generate_invoices_for_term
              unless result.nil?
                puts result[:internal]
                quote.mark_failure(result[:internal])
                render json: standard_error(:quote_failed, I18n.t(result[:external])),
                       status: 400
                return
              end
              @application = @policy_application
              render template: 'v2/user/policy_applications/create.json', status: 200
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
          .permit(:branding_profile_id, :effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                  questions: [:title, :value, options: []],
                  coverage_selections: {}, #[:uid, :selection, selection: [ :data_type, :value ]],
                  extra_settings: [
                    :installment_day, # for MSI
                    :number_of_units, :years_professionally_managed, :year_built, :gated, :in_city_limits, # for QBE and MSI non-preferred
                    additional_interest: [
                      :entity_type, :email_address, :phone_number,
                      :company_name,
                      :first_name, :last_name, :middle_name,
                      :address, # for msi; qbe terms are below:
                      :addr1, :addr2, :city, :state, :zip
                    ]
                  ],
                  policy_rates_attributes: [:insurable_rate_id],
                  policy_insurables_attributes: [:insurable_id])
      end

      def create_commercial_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {},
                                           questions: [:text, :value, :questionId, options: [], questions: [:text, :value, :questionId, options: []]])
      end

      def create_rental_guarantee_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :expiration_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {})
      end

      def create_security_deposit_replacement_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :expiration_date, :auto_pay,
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
                    :spouse, :primary, user_attributes: [
                      :email, profile_attributes: %i[
                        first_name last_name middle_name job_title
                        contact_phone birth_date gender salutation
                      ], address_attributes: %i[
                        city country county id latitude longitude
                        plus_four state street_name street_number
                        street_two timezone zip_code
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
          .permit(:branding_profile_id, :effective_date, :billing_strategy_id,
                  :agency_id, :account_id,
                  fields: {},
                  policy_rates_attributes: [:insurable_rate_id],
                  policy_insurables_attributes: [:insurable_id],
                  coverage_selections: {}, #[:uid, :selection, selection: [ :data_type, :value ]],
                  extra_settings: [
                    :installment_day, # for MSI
                    :number_of_units, :years_professionally_managed, :year_built, :gated, :in_city_limits, # for QBE and MSI non-preferred
                    additional_interest: [
                      :entity_type, :email_address, :phone_number,
                      :company_name,
                      :first_name, :last_name, :middle_name,
                      :address, # for msi; qbe terms are below:
                      :addr1, :addr2, :city, :state, :zip
                    ]
                  ])
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:agency_id, :account_id, :fields, :billing_strategy_id, :effective_date, fields: {})
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
                    message: I18n.t('user_policy_application_controller.you_cant_use_same_emails')
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
