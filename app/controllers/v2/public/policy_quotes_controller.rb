##
# V2 Public PolicyQuotes Controller
# File: app/controllers/v2/public/policy_quotes_controller.rb

module V2
  module Public
    class PolicyQuotesController < PublicController
      
      before_action :set_policy_quote
      
      def update
        @application = @policy_quote.policy_application
        
        if @policy_quote.quoted? && 
           @application.policy_type_id == 4
          
          logger.debug "\nAVAILABLE FOR UPDATE\n".green
          
          # Blank for now
          if update_policy_quote_params.has_key?(:tiaPremium)
            @policy_quote.policy_premium.update include_special_premium: update_policy_quote_params[:tiaPremium]  
          end
          
          if update_policy_quote_params.has_key?(:billing_strategy_id) && 
             update_policy_quote_params[:billing_strategy_id] != @application.billing_strategy_id
            @application.update billing_strategy: BillingStrategy.find(update_policy_quote_params[:billing_strategy_id])
          end
          
          if update_policy_quote_params.has_key?(:tiaPremium) ||
             update_policy_quote_params.has_key?(:billing_strategy_id)
            
            puts "Updating for premium & invoices".green
            
            @policy_quote.policy_premium.reset_premium()
            @policy_quote.generate_invoices_for_term(false, true)
          else
            
            puts "No updates for premium & invoices".red
          end

					response = { 
						quote: { 
							id: @policy_quote.id, 
							status: @policy_quote.status, 
							premium: @policy_quote.policy_premium
						},
						invoices: @policy_quote.invoices.order("due_date ASC"),
						user: { 
							id: @policy_quote.policy_application.primary_user().id,
							stripe_id: @policy_quote.policy_application.primary_user().stripe_id
						},
						billing_strategies: []
					}
								
					if @policy_quote.policy_premium.base >= 500000
						BillingStrategy.where(agency: @policy_quote.policy_application.agency_id, policy_type: @policy_quote.policy_application.policy_type).each do |bs|
						  response[:billing_strategies]	<< { id: bs.id, title: bs.title }
            end
					end
									  
					render json: response.to_json, status: 200
        else
					render json: { error: "Quote Unavailable for Update", message: "We are unable to update this quote due to it already being accepted or not meeting the policy type requirements." }, status: 422          
        end
      end
      
      # requires param 'payment_method' to be 'card' or 'ach'
      def external_payment_auth
        unless @policy_quote.policy_application.carrier_id == 5 && @policy_quote.status == 'quoted' && @policy_quote.carrier_payment_data && @policy_quote.carrier_payment_data['product_id']
          render json: {
            :error => "Not applicable",
            :message => "External payment authorization is not applicable to this policy quote"
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
              line_breaks: true
            )
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
                :error => "System error",
                :message => "Remote system failed to provide authorization (#{event.id || '-1'})"
              }, status: :unprocessable_entity
            else
              data = result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "MSI_CreditCardPreAuthorization")
              if data.nil? || data["MSI_PreAuthorizationToken"].nil? || data["MSI_PreAuthorizationPublicKeyBase64"].nil?
                render json: {
                  :error => "System error",
                  :message => "Remote system failed to provide authorization (#{event.id || '-2'})"
                }, status: :unprocessable_entity
              else
                render json: {
                  clientToken: data["MSI_PreAuthorizationToken"],
                  publicKeyBase64: data["MSI_PreAuthorizationPublicKeyBase64"]
                }, status: :ok
              end
            end
          when 'ach' # MOOSE WARNING: implement this...
            render json: {
              :error => "Invalid payment method",
              :message => "ACH support not applicable"
            }, status: :unprocessable_entity
          else
            render json: {
              :error => "Invalid payment method",
              :message => "Payment method must be 'card' or 'ach'; received '#{params[:payment_method] || 'null'}'"
            }, status: :unprocessable_entity
        end
      end
      
      def accept
	    	unless @policy_quote.nil?
		    	@user = ::User.find(accept_policy_quote_params[:id])
		    	unless @user.nil?
            uses_stripe = (@policy_quote.policy_application.carrier_id == 5 ? false : true) # MOOSE WARNING: move this to a configurable field on CarrierPolicyType or something?
						result = !uses_stripe ? nil : @user.attach_payment_source(accept_policy_quote_params[:source])
			    	if !uses_stripe || result.valid?
              bind_params = []
              # collect bind params for msi
              if @policy_quote.policy_application.carrier_id == 5
                # validate
                problem = validate_accept_policy_quote_payment_params
                unless problem.nil?
                  render json: {
                    :error => "Invalid Payment Information",
                    :message => problem
                  }, status: 400			   
                  return
                end
                # set bind params
                bind_params = [
                  {
                    'payment_method' => accept_policy_quote_payment_params[:payment_method],
                    'payment_info' => { CreditCardInfo: accept_policy_quote_payment_params[:CreditCardInfo].to_h },
                    'payment_token' => accept_policy_quote_payment_params[:token]
                  }
                ]
              end
              # bind
				    	@quote_attempt = @policy_quote.accept(bind_params: bind_params)
				    	@policy_type_identifier = @policy_quote.policy_application.policy_type_id == 5 ? "Rental Guarantee" : "Policy"
							if @quote_attempt[:success]
                insurable = @policy_quote.policy_application.policy&.primary_insurable
                Insurables::UpdateCoveredStatus.run!(insurable: insurable) if insurable.present?

								::Analytics.track(
									user_id: @user.id,
									event: 'Order Completed',
									properties: { category: 'Orders' }
								)
							end
							render json: {
								:error => @quote_attempt[:success] ? "#{ @policy_type_identifier } Accepted" : "#{ @policy_type_identifier } Could Not Be Accepted",
								:message => @quote_attempt[:message]
							}, status: @quote_attempt[:success] ? 200 : 500
							
				    else
				    	render json: { error: "Failure", message: result.errors.full_messages.join(' and ') }.to_json, status: 422
			    	end
			    else
			    	
			    	render json: {
				    	:error => "Not Found",
				    	:message => "User #{ params[:id] } counld not be found."
			    	}, status: 400			    
			    
			    end
		    else
		    	
		    	render json: {
			    	:error => "Not Found",
			    	:message => "Policy Quote #{ params[:id] } counld not be found."
		    	}, status: 400
		    
		    end  
	    end
      
      private
        
        def set_policy_quote
          @policy_quote = PolicyQuote.find(params[:id])
        end
        
        def update_policy_quote_params
          params.require(:policy_quote).permit( :tiaPremium, :billing_strategy_id )  
        end
      
				def accept_policy_quote_params
					params.require(:user).permit( :id, :source )
				end
        
        def accept_policy_quote_payment_params
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
        
        def validate_accept_policy_quote_payment_params
          pars = accept_policy_quote_payment_params
          return "a valid payment method must be supplied" unless pars[:payment_method] == 'card'
          return "payment token cannot be blank" if pars[:token].blank?
          return "Credit Card Info cannot be blank" if pars[:CreditCardInfo].blank?
          [:CardHolderName, :CardExpirationDate, :CardType, :CreditCardLast4Digits, :Addr].each do |prop|
            return "#{prop.to_s.titleize} cannot be blank" if pars[:CreditCardInfo][prop].blank?
          end
          { Addr1: "Address Line 1", City: "City", StateProvCd: "State", PostalCode: "Postal Code" }.each do |prop,hr|
            return "#{hr} cannot be blank" if pars[:CreditCardInfo][:Addr][prop].blank?
          end
          unless ::Address::EXTENDED_US_STATE_CODES.include?(pars[:CreditCardInfo][:Addr][:StateProvCd].to_sym)
            return "State must be a valid US state abbreviation"
          end
          unless pars[:CreditCardInfo][:Addr][:PostalCode].to_s.match?(/\A\d{5}-\d{4}|\A\d{5}\z/)
            return "Postal code must be a valid zip code"
          end
          return nil
        end
        
    end
  end # module Public
end
