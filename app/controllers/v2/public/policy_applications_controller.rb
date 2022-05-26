##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb
require 'securerandom'

module V2
  module Public
    class PolicyApplicationsController < PublicController

      include Leads::CreateMethods
      include Devise::Controllers::SignInOut
      include PolicyApplicationMethods

      before_action :set_policy_application, only: %i[update rent_guarantee_complete]
      before_action :set_policy_application_from_token, only: %i[show]
      before_action :validate_policy_users_params, only: %i[create update]

      def show
        if @policy_application.status == 'accepted'
          render json:   standard_error(:policy_application_not_found, I18n.t('policy_application_contr.show.policy_application_not_found')),
                 status: 404
          return
        end
      end

      def create
        if request.headers.key?("token-key") && request.headers.key?("token-secret")

          if check_api_access()
            if params[:policy_application][:policy_type_id].to_i == 1 ||
               params[:policy_application][:policy_type_id].to_i == 5
              create_from_external
            else
              render json: standard_error(:invalid_policy_type, I18n.t('policy_application_contr.new.invalid_policy_type')), status: 422
            end
          else
            render json: standard_error(:authentication, I18n.t('policy_application_contr.create.invalid_auth_key')), status: 401
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
            render json: standard_error(:invalid_policy_type, I18n.t('policy_application_contr.new.invalid_policy_type')), status: 422
          end
        end
      end

      def rent_guarantee_complete
        PolicyApplications::RentGuaranteeMailer.with(policy_application: @policy_application).invite_to_pay.deliver_later
        render json: { message: I18n.t('policy_application_contr.rentguarantee_complete.inistructions_were_sent') }
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
                    message: I18n.t('policy_application_contr.validate_policy_users_params.bad_arguments')
                  }.to_json,
            status: 401
          ) and return
        end
      end

      def create_rental_guarantee
        @application        = PolicyApplication.new(create_rental_guarantee_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?
        @application.billing_strategy = BillingStrategy.where(agency:      @application.agency,
                                                              carrier:     @application.carrier,
                                                              policy_type: @application.policy_type).take if @application.billing_strategy.nil?

        validate_applicant_result =
          PolicyApplications::ValidateApplicantsParameters.run!(
            policy_users_params: create_policy_users_params[:policy_users_attributes]
          )
        if validate_applicant_result.failure?
          render(json: validate_applicant_result.failure, status: 401) && return
        end

        if @application.save
          if @application.update(status: 'in_progress')
            @policy_application = @application
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
        policy_type = params[:policy_application][:policy_type_id].to_i
        init_hash = {
          :agency => @access_token.bearer,
          :policy_type => PolicyType.find(policy_type),
          :carrier => policy_type == 1 ? Carrier.find(1) : Carrier.find(4),
          :account => nil,
          :effective_date => place_holder_date,
          :expiration_date => place_holder_date + 1.year
        }
        if @access_token.bearer_type == 'Agency'
          if @access_token.bearer_id == ::ConfieService.agency_id
            unless params[:mediacode].blank?
              init_hash[:tagging_data] ||= {}
              init_hash[:tagging_data]['confie_mediacode'] = params.require(:mediacode).to_s
              init_hash[:tagging_data]['confie_external'] = true
            end
          end
        end

        site = @access_token.bearer.branding_profiles.count > 0 ? "https://#{@access_token.bearer.branding_profiles.where(default: true).take.url}" :
                                                                  Rails.application.credentials[:uri][Rails.env.to_sym][:client]

        program = policy_type == 1 ? "residential" : "rentguarantee"

        @application = PolicyApplication.new(init_hash)
        @application.build_from_carrier_policy_type
        @application.billing_strategy = BillingStrategy.where(agency:       @application.agency,
                                                              policy_type:  @application.policy_type,
                                                              carrier:      @application.carrier).take

        address_string = residential_address_params[:fields][:address]
        unit_string = residential_address_params[:fields][:unit]
        @application.resolver_info = {
          "address_string" => address_string,
          "unit_string" => unit_string,
          "insurable_id" => nil,
          "parent_insurable_id" => nil
        }

        case policy_type
          when 1 # residential
            unit = ::Insurable.get_or_create(address: address_string, unit: unit_string.blank? ? true : unit_string)
            if unit.class == ::Insurable
              @application.policy_insurables_attributes = [{ primary: true, insurable_id: unit.id, policy_id: nil }]
              @application.resolver_info["insurable_id"] = unit.id
              @application.resolver_info["parent_insurable_id"] = unit.insurable_id
              @application.resolver_info["unit_title"] = unit.title
            else
              parent = ::Insurable.get_or_create(address: address_string, unit: false, ignore_street_two: true)
              if parent.class == ::Insurable
                @application.resolver_info["parent_insurable_id"] = parent.id
              end
            end
          when 5 # rent guarantee
            params["policy_application"]["fields"].keys.each do |key|
              @application.fields[key] = params["policy_application"]["fields"][key]
            end
        end

        map_params_and_create_lead

        if @application.save
          # update users
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )
          if update_users_result.success?
            if @application.update(status: 'in_progress')
              # get token and redirect url
              new_access_token = @application.create_access_token
              @redirect_url = "#{site}/#{program}/#{new_access_token.to_urlparam}"
              # sign_in
              sign_in_primary_user(@application.primary_user)
              # done
              render 'v2/public/policy_applications/show_external'
            else
              render json: standard_error(:policy_application_update_error, nil, @application.errors),
                     status: 422
            end
          else
            render json: update_users_result.failure, status: 422
          end
        else
          # Rental Guarantee Application Save Error
          render json: standard_error(:policy_application_update_error, nil, @application.errors),
                 status: 422
        end
      end

      def map_params_and_create_lead
        set_lead(external_api_call_params(@application))
        create_lead_event
      end

      def create_commercial
        @application        = PolicyApplication.new(create_commercial_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?

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
                @premium = @quote.policy_premium
                
                # generate invoices
                result = @quote.generate_invoices_for_term
                unless result.nil?
                  puts result[:internal] # MOOSE WARNING: [:external] contains an I81n key for a user-displayable message, if desired
                  quote.mark_failure(result[:internal])
                  render json: standard_error(:quote_failed, I18n.t(result[:external])),
                         status: 400
                  return
                end

                if @premium.base >= 500_000
                  BillingStrategy.where(agency: @application.agency_id, policy_type: @application.policy_type).each do |bs|
                    @extra_fields ||= { billing_strategies: [] }
                    @extra_fields[:billing_strategies] << { billing_strategies: { id: bs.id, title: bs.title } }
                  end
                end

                sign_in_primary_user(@application.primary_user)

                render template: 'v2/public/policy_applications/create.json', status: 200

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
            policy_users_params: create_policy_users_params[:policy_users_attributes]
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

          sign_in_primary_user(@application.primary_user)

          render template: 'v2/public/policy_applications/create.json', status: 200
          
          return
        end
      end

      def create_residential
        @application = PolicyApplication.new(create_residential_params)
        @application.policy_insurables.first.primary = true if @application.policy_insurables.length == 1 # ensure that .primary_insurable actually works before save
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)
        @application.agency = @application.account&.agency || Agency.where(master_agency: true).take if @application.agency.nil?
        @application.account = @application.primary_insurable&.account if @application.account.nil?
        # flee if nonsense is passed for additional interest
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
        # scream if we are missing critical community information          
        if @application.carrier_id == ::QbeService.carrier_id && @application.primary_insurable.account.nil?
          defaults = ::QbeService::FIC_DEFAULTS[@application.primary_insurable.primary_address.state] || ::QbeService::FIC_DEFAULTS[nil]
          missing_fic_info = ::QbeService::FIC_DEFAULT_KEYS.select{|k| !@application.extra_settings&.has_key?(k) && !defaults.has_key?(k) }
          unless missing_fic_info.blank?
            render json: standard_error(:community_information_missing, I18n.t('policy_application_contr.qbe_application.missing_fic_info', missing_list: missing_fic_info.map{|v| I18n.t("policy_application_contr.qbe_application.#{v}") }.join(", "))),
              status: 400
            return
          end
        end
        # go wild
        if @application.save
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )

          unless update_users_result.success?
            render json: update_users_result.failure, status: 422
          else
            if @application.update status: 'complete'
              # create lead
              LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @application)
              # if application.status updated to complete
              @application.estimate()
              @quote = @application.policy_quotes.order('created_at DESC').limit(1).first
              if @application.status == "quote_failed"
                render json: standard_error(:policy_application_unavailable, @application.error_message || I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable')),
                       status: 400
              elsif @application.status == "quoted"
                render json: standard_error(:policy_application_unavailable, I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable')),
                       status: 400
              else
                # if application quote success or failure
                @application.quote(@quote.id)
                @application.reload
                @quote.reload

                if @application.status == "quote_failed"
                  render json: standard_error(:quote_failed, @application.error_message || I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed')),
                         status: 500
                elsif @quote.status == "quoted"
                  # create Confie lead if necessary
                  ::ConfieService.create_confie_lead(@application) if @application.agency_id == ::ConfieService.agency_id
                  # perform final setup
                  @application.primary_user.set_stripe_id
                  sign_in_primary_user(@application.primary_user)
                  # return response to user
                  @extra_fields = {
                   'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                   'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                   'installment_total' => @quote.carrier_payment_data['installment_total']
                  } if @application.carrier_id == 5
                  use_translations_for_application_questions!(@application) # this is from the policy application methods concern... just here in case they switched languages after calling .new
                  render template: 'v2/public/policy_applications/create.json', status: 200

                else
                  render json: standard_error(:quote_failed, I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed')),
                         status: 500
                end
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
        case params[:policy_application][:policy_type_id].to_i
        when 1
          update_residential
        when 5
          update_rental_guarantee
        else
          render json: standard_error(:invalid_policy_type, I18n.t('policy_application_contr.new.invalid_policy_type')), status: 422
        end
      end

      def update_residential
        @policy_application = PolicyApplication.find(params[:id])
        if @policy_application.policy_type.title == 'Residential'
          # try to update
          @policy_application.assign_attributes(update_residential_params)
          @policy_application.expiration_date = @policy_application.effective_date&.send(:+, 1.year)
          # fix agency/account if needed
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
          # woot woot, try to update users and save
          update_users_result = update_policy_users_params.blank? ? true :
            PolicyApplications::UpdateUsers.run!(
              policy_application: @policy_application,
              policy_users_params: update_policy_users_params[:policy_users_attributes]
            )
          LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @policy_application)
          if !(update_users_result == true || update_users_result.success?)
            render json: update_users_result.failure,
              status: 422
          else
            @policy_insurables_to_restore = nil
            unless @replacement_policy_insurables.blank?
              @policy_insurables_to_restore = @policy_application.policy_insurables.select{|pi| pi.id }
              @policy_application.policy_insurables.clear
              @policy_application.policy_insurables = @replacement_policy_insurables
              @policy_application.account = @policy_application.primary_insurable&.account if update_residential_params[:account_id].nil?
            end
            if !@policy_application.save
              unless @policy_insurables_to_restore.blank?
                @policy_application.policy_insurables.clear
                @policy_insurables_to_restore.update_all(policy_application_id: @policy_application.id)
              end
              render json: standard_error(:policy_application_save_error, nil, @policy_application.errors),
                     status: 422
            else
              if @policy_application.primary_insurable.nil?
                  render json: standard_error(:invalid_address, I18n.t('policy_application_contr.update_residential.invalid_address')),
                         status: 400
              elsif @policy_application.update(status: 'complete')

                @policy_application.estimate
                @quote = @policy_application.policy_quotes.order("updated_at DESC").limit(1).first

                if @policy_application.status == "quote_failed"
                  render json: standard_error(:policy_application_unavailable, I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable') + " #{@policy_application.error_message}"),
                         status: 400
                elsif @policy_application.status == "quoted"
                  render json: standard_error(:policy_application_unavailable, I18n.t('policy_application_contr.create_security_deposit_replacement.policy_application_unavailable')),
                         status: 400
                else
                  # if application quote success or failure
                  @policy_application.quote(@quote.id)
                  @policy_application.reload
                  @quote.reload

                  if @policy_application.status == "quote_failed"
                    render json: standard_error(:quote_failed, @policy_application.error_message || I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed')),
                           status: 500
                  elsif @quote.status == "quoted"
                    sign_in_primary_user(@policy_application.primary_user)

                    @application = @policy_application
                    @extra_fields = {
                     'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                     'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                     'installment_total' => @quote.carrier_payment_data['installment_total']
                    } if @application.carrier_id == 5
                    use_translations_for_application_questions!(@application) # this is from the policy application methods concern... just here in case they switched languages after calling .new
                    render template: 'v2/public/policy_applications/create.json', status: 200

                  else
                    render json: standard_error(:quote_failed, I18n.t('policy_application_contr.create_security_deposit_replacement.quote_failed')),
                           status: 500
                  end
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
        @policy_application.assign_attributes(update_residential_params)
        @policy_application.expiration_date = @policy_application.effective_date&.send(:+, 1.year)
        @policy_application.agency = @policy_application.account&.agency || Agency.where(master_agency: true).take if @policy_application.agency.nil?
        @policy_application.account = @policy_application.primary_insurable&.account if @policy_application.account.nil?
        
        if @policy_application.save && @policy_application.update(status: 'complete')
          update_users_result =
            PolicyApplications::UpdateUsers.run!(
              policy_application: @policy_application,
              policy_users_params: create_policy_users_params[:policy_users_attributes]
            )
          LeadEvents::LinkPolicyApplicationUsers.run!(policy_application: @policy_application)
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
              sign_in_primary_user(@policy_application.primary_user)
              @application = @policy_application
              render template: 'v2/public/policy_applications/create.json', status: 200
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

      private

      def sign_in_primary_user(primary_user)
        sign_in(primary_user)
        response.headers.merge!(primary_user.create_new_auth_token)
      end


      def check_api_access
        key = request.headers["token-key"]
        secret = request.headers["token-secret"]
        pass = false

        unless key.nil? || secret.nil?
          @access_token = AccessToken.find_by_key(key)
          if !@access_token.nil? &&
            @access_token.access_type == 'agency_integration' &&
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
        @application = @policy_application = access_model(::PolicyApplication, params[:id])
      end

      def set_policy_application_from_token
        token = ::AccessToken.from_urlparam(params[:token])
        pa_id = token.nil? || token.access_type != 'application_access' || token.expired? ? nil : token.access_data&.[]('policy_application_id')
        @application = @policy_application = access_model(::PolicyApplication, pa_id || 0)
      end

      def residential_address_params
        params.require(:policy_application).permit(fields: [:address, :unit])
      end

      def create_residential_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                  questions:                       [:title, :value, options: []],
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
                  policy_rates_attributes:         [:insurable_rate_id],
                  policy_insurables_attributes:    [:insurable_id])
      end

      def create_commercial_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: {},
                  questions:                       [:text, :value, :questionId, options: [], questions: [:text, :value, :questionId, options: []]])
      end

      def create_rental_guarantee_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, :account_id, fields: {})
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
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :billing_strategy_id,  :fields, fields: {})
      end

    end
  end # module Public
end
