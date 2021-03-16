##
# V2 Public PolicyApplications Controller
# File: app/controllers/v2/public/policy_applications_controller.rb
require 'securerandom'

module V2
  module Public
    class PolicyApplicationsController < PublicController

      include Leads::CreateMethods
      include Devise::Controllers::SignInOut

      before_action :set_policy_application, only: %i[update rent_guarantee_complete]
      before_action :set_policy_application_from_token, only: %i[show]
      before_action :validate_policy_users_params, only: %i[create update]

      def show
        if @policy_application.status == 'accepted'
          render json:   standard_error(:policy_application_not_found, I18n.t('policy_application_contr.show.policy_application_not_found')),
                 status: 404
          return
        end
        if @policy_application.carrier_id == MsiService.carrier_id
          @policy_application.coverage_selections.each do |cs|
            if (Float(cs['selection']) rescue false)
              cs['selection'] = { 'data_type' => 'currency', 'value' => (cs['selection'].to_d * 100.to_d).to_i }
            end
          end
          @policy_application.coverage_selections = @policy_application.coverage_selections.select{|cs| cs['uid'] != '1010' && cs['uid'] != 1010 }
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
              render(json: standard_error(:unit_not_found, I18n.t('policy_application_contr.new.unit_not_found')), status: :unprocessable_entity) and return
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
                render json:   { error: I18n.t('policy_application_contr.new.invalid_unit') },
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
          render json:   standard_error(:invalid_policy_type, I18n.t('policy_application_contr.new.invalid_policy_type')),
                 status: :unprocessable_entity
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
        @application.agency = Agency.where(master_agency: true).take if @application.agency.nil?
        @application.billing_strategy = BillingStrategy.where(agency:      @application.agency,
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
              init_hash[:tagging_data]['confie_external'] = true
            end
          end
        end

        # Warning to remember to fix this for agencies that have multiple branding profiles in the future.
        site = @access_token.bearer.branding_profiles.count > 0 ? "https://#{@access_token.bearer.branding_profiles.first.url}" :
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
              @application.insurables << unit
              @application.policy_insurables.first.primary = true
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

                result = {
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
                    result[:billing_strategies] << { id: bs.id, title: bs.title }
                  end
                end

                sign_in_primary_user(@application.primary_user)

                render json: result.to_json, status: 200

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

      def validate_msi_additional_interest(hash)
        if 
      end

      def create_residential
        @application = PolicyApplication.new(create_residential_params)
        @application.expiration_date = @application.effective_date&.send(:+, 1.year)

        if @application.extra_settings && !@application.extra_settings['additional_interest'].blank?
          error_message = validate_msi_additional_interest(@application.extra_settings['additional_interest'])
          unless error_message.nil?
            render json: standard_error(:policy_application_save_error, I18n.t(error_message)),
                   status: 400
            return
          end
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
          @application.coverage_selections.select!{|cs| cs['selection'] || cs[:selection] }
          @application.coverage_selections.push({ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true }) unless @application.coverage_selections.any?{|co| co['uid'] == '1010' }
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
          # flee if nonsense is passed for additional interest
          if @policy_application.extra_settings && !@policy_application.extra_settings['additional_interest'].blank?
            error_message = validate_msi_additional_interest(@policy_application.extra_settings['additional_interest'])
            unless error_message.nil?
              render json: standard_error(:policy_application_save_error, I18n.t(error_message)),
                     status: 400
              return
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
            @policy_application.coverage_selections = @policy_application.coverage_selections.select{|cs| cs['selection'] || cs[:selection] }
            @policy_application.coverage_selections.push({ 'category' => 'coverage', 'options_type' => 'none', 'uid' => '1010', 'selection' => true }) unless @policy_application.coverage_selections.any?{|co| co['uid'] == '1010' }
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
                                 }.merge(@policy_application.carrier_id != 5 ? {} : {
                                   'policy_fee' => @quote.carrier_payment_data['policy_fee'],
                                   'installment_fee' => @quote.carrier_payment_data['installment_fee'],
                                   'installment_total' => @quote.carrier_payment_data['installment_total']
                                 }).to_json, status: 200

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
        if update_residential_params[:effective_date].present?
          @policy_application.expiration_date = update_residential_params[:effective_date].to_date&.send(:+, 1.year)
        end
        if @policy_application.update(update_rental_guarantee_params) && @policy_application.update(status: 'complete')
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
              invoice_errors = @quote.generate_invoices_for_term
              @premium       = @quote.policy_premium

              result = {
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

              sign_in_primary_user(@policy_application.primary_user)

              render json: result.to_json, status: 200
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
            render json:   { error: "#{I18n.t('policy_application_contr.get_coverage_options.invalid_combination')} #{get_coverage_options_params[:carrier_id] || 'NULL'}/#{get_coverage_options_params[:policy_type_id] || 'NULL'}" },
                   status: :unprocessable_entity
        end
      end

      def deposit_choice_get_coverage_options
        @residential_unit_insurable_type_id = 4
        # validate params
        inputs = deposit_choice_get_coverage_options_params
        if inputs[:insurable_id].nil?
          render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.insurable_id_cannot_be_blank') },
                 status: :unprocessable_entity
          return
        end
        if inputs[:effective_date].nil?
          render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.effective_date_cannot_be_blank') },
                 status: :unprocessable_entity
          return
        end
        # pull unit from db
        unit = Insurable.where(id: inputs[:insurable_id].to_i).take
        if unit.nil? || unit.insurable_type_id != @residential_unit_insurable_type_id
          render json:   { error: I18n.t('policy_application_contr.new.unit_not_found') },
                 status: :unprocessable_entity
          return
        end
        # get coverage options
        result = unit.dc_get_rates(Date.parse(inputs[:effective_date]))
        unless result[:success]
          render json:   { error: "#{ I18n.t('policy_application_contr.deposit_choice_get_coverage_options.no_security_deposit_replacement')} #{result[:event]&.id || 0})" },
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
          render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.insurable_id_cannot_be_blank') },
                 status: :unprocessable_entity
          return
        end
        unless inputs[:coverage_selections].nil?
          if inputs[:coverage_selections].class != ::Array
            render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.coverage_selections_must_be_array') },
                   status: :unprocessable_entity
            return
          else
            broken = inputs[:coverage_selections].select { |cs| cs[:category].blank? || cs[:uid].blank? }
            unless broken.length == 0
              render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.must_include_category_and_uid') },
                     status: :unprocessable_entity
              return
            end
          end
        end
        if inputs[:estimate_premium]
          if inputs[:agency_id].nil?
            render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.agency_cannot_be_blank') },
                   status: :unprocessable_entity
            return
          end
          if inputs[:effective_date].nil?
            render json:   { error: I18n.t('policy_application_contr.deposit_choice_get_coverage_options.effective_date_cannot_be_blank') },
                   status: :unprocessable_entity
            return
          else
            begin
              Date.parse(inputs[:effective_date])
            rescue ArgumentError
              render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.effective_date_must_be_valid_date') },
                     status: :unprocessable_entity
              return
            end
          end
          if inputs[:additional_insured].nil?
            render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.additional_insured_cannot_be_blank') },
                   status: :unprocessable_entity
            return
          end
          if inputs[:billing_strategy_id].nil?
            render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.billing_strategy_id_cannot_be_blank') },
                   status: :unprocessable_entity
            return
          end
        end
        # pull unit from db
        unit = Insurable.where(id: inputs[:insurable_id].to_i).take
        if unit.nil? || unit.insurable_type_id != @residential_unit_insurable_type_id
          render json:   { error: I18n.t('policy_application_contr.new.unit_not_found') },
                 status: :unprocessable_entity
          return
        end
        # grab community
        community = unit.parent_community
        cip       = !unit.preferred_ho4 ? nil : CarrierInsurableProfile.where(carrier_id: @msi_id, insurable_id: community&.id).take # possibly nil, for non-preferred
        if community.nil?
          render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.community_not_found') },
                 status: :unprocessable_entity
          return
        end
        # grab billing strategy and make sure it's valid
        billing_strategy_code = nil
        billing_strategy      = BillingStrategy.where(carrier_id: @msi_id, agency_id: inputs[:agency_id].to_i, policy_type_id: @ho4_policy_type_id, id: inputs[:billing_strategy_id].to_i).take
        if billing_strategy.nil? && inputs[:estimate_premium]
          render json:   { error: I18n.t('policy_application_contr.msi_get_coverage_options.billing_strategy_must_belong_to_carrier') },
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
          agency: Agency.where(id: msi_get_coverage_options_params[:agency_id].to_i || 0).take,
          perform_estimate: inputs[:estimate_premium] ? true : false,
          eventable:        unit,
          **(cip ? {} : {
            nonpreferred_final_premium_params: {
              number_of_units: inputs[:number_of_units].to_i == 0 ? nil : inputs[:number_of_units].to_i,
              years_professionally_managed: inputs[:years_professionally_managed].blank? ? nil : inputs[:years_professionally_managed].to_i,
              year_built: inputs[:year_built].to_i == 0 ? nil : inputs[:year_built].to_i,
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

        response_tr = results.select{|k, v| k != :errors }.merge(results[:errors] ? { estimated_premium_errors: [results[:errors][:external]].flatten } : {})
        use_translations_for_msi_coverage_options!(response_tr)

        render json: response_tr,
               status: 200
      end

      private

      def sign_in_primary_user(primary_user)
        sign_in(primary_user)
        response.headers.merge!(primary_user.create_new_auth_token)
      end

      def use_translations_for_msi_coverage_options!(response_tr)
        response_tr[:coverage_options].each do |coverage_opt|
          uid = coverage_opt["uid"]
          title = I18n.t("coverage_options.#{uid}_title")
          description = I18n.t("coverage_options.#{uid}_desc")
          coverage_opt["description"] = description unless description.include?('translation missing')
          coverage_opt["title"] = title unless description.include?('translation missing')
        end
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

      def new_residential_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :agency_id, :account_id, :policy_type_id,
                  :address_string, :unit_title, # for non-preferred
                  policy_insurables_attributes: [:id]) # for preferred
      end

      def create_residential_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :auto_pay,
                  :auto_renew, :billing_strategy_id, :account_id, :policy_type_id,
                  :carrier_id, :agency_id, fields: [:title, :value, options: []],
                  questions:                       [:title, :value, options: []],
                  coverage_selections: [:category, :uid, :selection, selection: [ :data_type, :value ]],
                  extra_settings: [
                    # for MSI
                    :installment_day, :number_of_units, :years_professionally_managed, :year_built, :gated,
                    additional_interest: [
                      :entity_type, :email_address, :phone_number,
                      :company_name, :address,
                      :first_name, :last_name, :middle_name
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
          .permit(:branding_profile_id, :effective_date, policy_rates_attributes: [:insurable_rate_id],
                  policy_insurables_attributes: [:insurable_id],
                  extra_settings: [
                    # for MSI
                    :installment_day, :number_of_units, :years_professionally_managed, :year_built, :gated,
                    additional_interest: [
                      :entity_type, :email_address, :phone_number,
                      :company_name, :address,
                      :first_name, :last_name, :middle_name
                    ]
                  ])
      end

      def update_rental_guarantee_params
        params.require(:policy_application)
          .permit(:branding_profile_id, :effective_date, :billing_strategy_id,  :fields, fields: {})
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
