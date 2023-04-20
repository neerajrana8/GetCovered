##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      before_action :set_policy_quote

      def update # only for commercial
        @application = @policy_quote.policy_application

        if @policy_quote.quoted? &&
           @application.policy_type_id == 4

          logger.debug "\nAVAILABLE FOR UPDATE\n".green

          # Blank for now
          if update_policy_quote_params.key?(:tiaPremium)
            @policy_quote.policy_premium.update include_special_premium: update_policy_quote_params[:tiaPremium]
          end

          if update_policy_quote_params.key?(:billing_strategy_id) &&
             update_policy_quote_params[:billing_strategy_id] != @application.billing_strategy_id
            @application.update billing_strategy: BillingStrategy.find(update_policy_quote_params[:billing_strategy_id])
          end

          if update_policy_quote_params.key?(:tiaPremium) ||
             update_policy_quote_params.key?(:billing_strategy_id)

            puts 'Updating for premium & invoices'.green

            @policy_quote.policy_premium.reset_premium
            @policy_quote.generate_invoices_for_term(false, true)
          else

            puts 'No updates for premium & invoices'.red
          end

          response = {
            quote: {
              id: @policy_quote.id,
              status: @policy_quote.status,
              premium: @policy_quote.policy_premium
            },
            invoices: @policy_quote.invoices.order('due_date ASC'),
            user: {
              id: @policy_quote.policy_application.primary_user.id,
              stripe_id: @policy_quote.policy_application.primary_user.stripe_id
            },
            billing_strategies: []
          }

          if @policy_quote.policy_premium.base >= 500_000
            BillingStrategy.where(agency: @policy_quote.policy_application.agency_id, policy_type: @policy_quote.policy_application.policy_type).each do |bs|
              @extra_fields ||= { billing_strategies: [] }
              @extra_fields[:billing_strategies] << { id: bs.id, title: bs.title }
            end
          end
          @application = @policy_quote.policy_application
          @quote = @policy_quote
          render template: 'v2/public/policy_applications/create.json', status: 200
        else
          render json: { error: I18n.t('policy_quote_controller.quote_unavailable_update'), message:  I18n.t('policy_quote_controller.unable_to_update_quote') }, status: 422
        end
      end

      # requires param 'payment_method' to be 'card' or 'ach'
      def external_payment_auth
        unless @policy_quote.policy_application.carrier_id == 5 && @policy_quote.status == 'quoted' && @policy_quote.carrier_payment_data && @policy_quote.carrier_payment_data['product_id']
          render json: {
            error:  I18n.t('policy_quote_controller.not_applicable'),
            message: I18n.t('policy_quote_controller.external_payment_not_applicable')
          }, status: :unprocessable_entity
          return
        end
        case params[:payment_method]
        when 'card'
          # make the call
          msis = MsiService.new
          event = @policy_quote.events.new(
            verb: 'post',
            format: 'xml',
            interface: 'REST',
            endpoint: msis.endpoint_for(:get_credit_card_pre_authorization_token),
            process: 'msi_get_credit_card_pre_authorization_token'
          )
          result = msis.build_request(:get_credit_card_pre_authorization_token,
                                      product_id: @policy_quote.carrier_payment_data['product_id'],
                                      state: @policy_quote.policy_application.primary_insurable.primary_address.state,
                                      line_breaks: true)
          event.request = msis.compiled_rxml
          event.save
          event.started = Time.now
          result = msis.call
          event.completed = Time.now
          event.response = result[:data]
          event.status = result[:error] ? 'error' : 'success'
          event.save
          # return the result
          if result[:error]
            render json: {
              error: I18n.t('policy_quote_controller.system_error'),
              message: "#{I18n.t('policy_quote_controller.remote_system_failed')} (#{event.id || '-1'})"
            }, status: :unprocessable_entity
          else
            data = result[:data].dig('MSIACORD', 'InsuranceSvcRs', 'RenterPolicyQuoteInqRs', 'MSI_CreditCardPreAuthorization')
            if data.nil? || data['MSI_PreAuthorizationToken'].nil? || data['MSI_PreAuthorizationPublicKeyBase64'].nil?
              render json: {
                error: I18n.t('policy_quote_controller.system_error'),
                message: "#{I18n.t('policy_quote_controller.remote_system_failed')} (#{event.id || '-2'})"
              }, status: :unprocessable_entity
            else
              render json: {
                clientToken: data['MSI_PreAuthorizationToken'],
                publicKeyBase64: data['MSI_PreAuthorizationPublicKeyBase64']
              }, status: :ok
            end
          end
        when 'ach' # MOOSE WARNING: implement this...
          render json: {
            error: I18n.t('policy_quote_controller.invalid_payment_method'),
            message: I18n.t('policy_quote_controller.ach_support_not_applicable')
          }, status: :unprocessable_entity
        else
          render json: {
            error: I18n.t('policy_quote_controller.invalid_payment_method'),
            message: "#{I18n.t('policy_quote_controller.payment_method_must_be_card')} '#{params[:payment_method] || 'null'}'"
          }, status: :unprocessable_entity
        end
      end

      def accept
        if @policy_quote.nil?
          render json: { error: I18n.t('policy_quote_controller.not_found'), message: "#{I18n.t('policy_quote_controller.policy_quote_not_found')} : #{params[:id]}" }, status: 400
        else
          @user = ::User.find(accept_policy_quote_params[:id])
          if @user.nil?
            render json: { error: I18n.t('policy_quote_controller.not_found'), message: "#{I18n.t('policy_quote_controller.user_could_not_be_found')} : #{params[:id]}" }, status: 400
          else
            uses_stripe = @policy_quote.policy_application.carrier.uses_stripe?
            result = !uses_stripe ? nil : @user.attach_payment_source(accept_policy_quote_params[:source])
            if !uses_stripe || result.valid?
              bind_params = []
              # collect bind params for applicable policy types
              case @policy_quote.policy_application.carrier_id
                when DepositChoiceService.carrier_id
                  # validate
                  problem = validate_deposit_choice_accept_policy_quote_payment_params
                  unless problem.nil?
                    render json: {
                      :error => I18n.t('policy_quote_controller.invalid_payment_info'),
                      :message => problem
                    }, status: 400
                    return
                  end
                  # set bind params
                  bind_params = [
                    {
                      'payment_token' => deposit_choice_accept_policy_quote_payment_params[:token]
                    }
                  ]
                when MsiService.carrier_id
                  # validate
                  problem = validate_msi_accept_policy_quote_payment_params
                  unless problem.nil?
                    render json: {
                      :error => I18n.t('policy_quote_controller.invalid_payment_info'),
                      :message => problem
                    }, status: 400
                    return
                  end
                  # set bind params
                  bind_params = [
                    {
                      'payment_method' => msi_accept_policy_quote_payment_params[:payment_method],
                      'payment_info' => { CreditCardInfo: msi_accept_policy_quote_payment_params[:CreditCardInfo].to_h },
                      'payment_token' => msi_accept_policy_quote_payment_params[:token]
                    }
                  ]
              end
              # bind
				    	@quote_attempt = @policy_quote.accept(bind_params: bind_params)
				    	@policy_type_identifier = { 5 => "Rental Guarantee", 6 => "Security Deposit Replacement Bond" }[@policy_quote.policy_application.policy_type_id] || "Policy"
              @signature_access_token = nil
							if @quote_attempt[:success]
                # insurable = @policy_quote.policy_application.policy&.primary_insurable
                # ::Insurables::UpdateCoveredStatus.run!(insurable: insurable) if insurable.present?

                invite_primary_user(@policy_quote.policy_application) rescue nil # MOOSE WARNING: we should record it somewhere if the invitation fails...
                
                if @policy_quote.policy_application.carrier_id == DepositChoiceService.carrier_id
                  dcb = @policy_quote.policy.signable_documents.deposit_choice_bond.take
                  @signature_access_token = dcb.create_access_token unless dcb.nil? # should  never be nil...
                end
              end
              unless @quote_attempt[:success]
                render json: {
                    error: "#{@policy_type_identifier} #{I18n.t('policy_quote_controller.could_not_be_accepted')}",
                    message: @quote_attempt[:message], # MOOSE WARNING: translation???
                    password_filled: @user.encrypted_password.present?
                  }.compact, status: 500
                return
              end

              # NOTE: MPA
              # NOTE: Cancel MPC if exists
              # NOTE: Needs Refactoring
              # MasterPolicies::CancelCoverage.run!(policy: @policy_quote.policy)
              insurables_ids = @policy_quote.policy.insurables.where(insurable_type_id: InsurableType::UNITS_IDS).pluck(:id)
              leases = Lease
                         .where(insurable_id: insurables_ids, status: 'current')
                         .where('start_date <= ?', Time.current.to_date)
              leases = leases.where(end_date: nil)
                   .or(leases.where('end_date > ?', Time.current.to_date))
              leases.each do |lease|
                policies = lease.policies.where(policy_type_id: PolicyType::MASTER_COVERAGES_IDS)
                policies.each do |policy|
                  policy.update status: 'CANCELLED'
                end
              end

              ::Insurables::UpdateCoveredStatus.run!(insurable: @policy_quote&.policy&.primary_insurable)

              render json: {
                error: ("#{@policy_type_identifier} #{I18n.t('policy_quote_controller.could_not_be_accepted')}" unless @quote_attempt[:success]),
                message: ("#{@policy_type_identifier} #{I18n.t('policy_quote_controller.accepted')} " if @quote_attempt[:success]).to_s + @quote_attempt[:message],
                password_filled: @user.encrypted_password.present?,
                policy_number:  @policy_quote&.policy&.number
              }.compact.merge(@signature_access_token.nil? ? {} : {
                document_token: @signature_access_token.to_urlparam
              }), status: @quote_attempt[:success] ? 200 : 500
            else
              render json: { error: I18n.t('policy_quote_controller.failure'), message: result.errors.full_messages.join(' and ') }.to_json, status: 422
             end
          end
        end
      end

      private

        def invite_primary_user(policy_application)
          primary_user = policy_application.primary_user
          if primary_user.invitation_accepted_at.nil? &&
            (primary_user.invitation_created_at.blank? || primary_user.invitation_created_at < 1.days.ago)

            primary_user.invite!(nil, policy_application: policy_application)
          end
        end

        def set_policy_quote
          @policy_quote = PolicyQuote.find(params[:id])
        end

        def update_policy_quote_params
          params.require(:policy_quote).permit(:tiaPremium, :billing_strategy_id)
        end

        def accept_policy_quote_params
          params.require(:user).permit(:id, :source)
        end

        def deposit_choice_accept_policy_quote_payment_params
          params.require(:payment).permit(:token)
        end

        def msi_accept_policy_quote_payment_params
          params.require(:payment).permit(:payment_method, :token,
            CreditCardInfo: [
              :CardHolderName,
              :CardExpirationDate,
              :CardType,
              :CreditCardLast4Digits,
              Addr: [
                :Addr1,
                :Addr2,
                :City,
                :StateProvCd,
                :PostalCode
              ]
            ]
          )
        end

        def validate_deposit_choice_accept_policy_quote_payment_params
          return I18n.t('policy_quote_controller.payment_token_cannot_be_blank') if deposit_choice_accept_policy_quote_payment_params[:token].blank?
          return nil
        end

        def validate_msi_accept_policy_quote_payment_params
          pars = msi_accept_policy_quote_payment_params
          return I18n.t('policy_quote_controller.valid_payment_method_must_supplied') unless pars[:payment_method] == 'card'
          return I18n.t('policy_quote_controller.payment_token_cannot_be_blank') if pars[:token].blank?
          return I18n.t('policy_quote_controller.credit_card_info_cannot_be_blank') if pars[:CreditCardInfo].blank?
          [:CardHolderName, :CardExpirationDate, :CardType, :CreditCardLast4Digits, :Addr].each do |prop|
            return "#{prop.to_s.titleize} #{I18n.t('insurable_type_model.cannot_be_blank')}" if pars[:CreditCardInfo][prop].blank?
          end
          { Addr1:  I18n.t('policy_quote_controller.address_line_1'), City: I18n.t('policy_quote_controller.city'), StateProvCd: I18n.t('policy_quote_controller.state'), PostalCode: I18n.t('policy_quote_controller.postal_code') }.each do |prop,hr|
            return "#{hr} #{I18n.t('insurable_type_model.cannot_be_blank')}" if pars[:CreditCardInfo][:Addr][prop].blank?
          end
          unless ::Address::EXTENDED_US_STATE_CODES.include?(pars[:CreditCardInfo][:Addr][:StateProvCd].to_sym)
            return I18n.t('policy_quote_controller.state_must_be_valid_us')
          end
          unless pars[:CreditCardInfo][:Addr][:PostalCode].to_s.match?(/\A\d{5}-\d{4}|\A\d{5}\z/)
            return I18n.t('policy_quote_controller.postal_code_must_be_valid')
          end
          return nil
        end

    end # class PolicyQuotesController
  end # module Public
end # module V2
