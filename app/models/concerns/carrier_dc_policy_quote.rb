# =DC Policy Quote Functions Concern
# file: +app/models/concerns/carrier_dc_policy_quote.rb+

module CarrierDcPolicyQuote
  extend ActiveSupport::Concern

  included do

    # MOOSE WARNING: PolicyQuote#bind_policy should call this boi if necessary
    def set_msi_external_reference
      
      return_status = true # MOOSE WARNING: change it?
      
    end
    
    # DC build coverages
    
    def dc_build_coverages
      self.policy.policy_coverages.create(
        policy_application: self.policy_application,
        title: "Security Deposit Replacement Bond",
        designation: "secdeprep-bond",
        limit: self.policy_application.coverage_selections['bond_amount'],
        deductible: 0,
        enabled: true
      )
    end
    
    # DC Bind

    # payment_params should be a hash of form:
    #   {
    #     'payment_token' = the token
    #   }
    def dc_bind(payment_params)
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}  
      }
      # handle common failure scenarios
      unless policy_application.carrier_id == DepositChoiceService.carrier_id
        @bind_response[:message] = "Carrier must be Deposit Choice to bind security deposit replacement quote"
        return @bind_response
      end
		 	unless accepted? && policy.nil?
		 		@bind_response[:message] = "Status must be quoted or error to bind quote"
        return @bind_response
		 	end
      # get useful variables
      unit = policy_application.primary_insurable
      unit_cip = unit.carrier_profile(DepositChoiceService.carrier_id)
      dcs = DepositChoiceService.new
      # create insured
      dcs.build_request(:insured, {
        
        
        
      
        unit_id: unit_profile.external_carrier_id,
        effective_date: effective_date
      }.compact)
      event = events.new(
        verb: DepositChoiceService::HTTP_VERB_DICTIONARY[:rate].to_s,
        format: 'json',
        interface: 'REST',
        endpoint: dcs.endpoint_for(:rate),
        process: 'deposit_choice_rate'
      )
      event.request = dcs.message_content
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:data]
      event.status = result[:error] ? 'error' : 'success'
      event.save
      # make sure we succeeded
      if result[:error]
        return { success: false, error: "Deposit Choice rate retrieval unsuccessful", event: event }
      elsif result[:data]&.[]("rates").nil?
        return { success: false, error: "Deposit Choice rate retrieval failed", event: event }
      end
      
      
      
      
      
      
      
      
      # unpack payment info
      payment_data = ((self.carrier_payment_data || {})['payment_methods'] || {})[payment_params['payment_method']]
      if payment_data.nil? || payment_data.class != ::Hash ||
          !payment_data.has_key?('method_id') || !payment_data.has_key?('merchant_id') || !payment_data.has_key?('processor_id') ||
          !payment_params.has_key?('payment_info') || !payment_params.has_key?('payment_token')
        # invalid payment data
        @bind_response[:message] = "Invalid payment data for binding policy"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
      payment_merchant_id = payment_data['merchant_id']
      payment_processor = payment_data['processor_id']
      payment_method = payment_data['method_id']
      # grab useful variables
      carrier_agency = CarrierAgency.where(agency: account.agency, carrier_id: 5).take
      unit = policy_application.primary_insurable
      community = unit.parent_community
      address = unit.primary_address
      primary_insured = policy_application.primary_user
      additional_insured = policy_application.users.select{|u| u.id != primary_insured.id }
      additional_interest = [unit.account || community.account].compact
      # prepare for bind call
      msis = MsiService.new
      event = events.new(
        verb: 'post',
        format: 'xml',
        interface: 'REST',
        endpoint: msis.endpoint_for(:bind_policy),
        process: 'msi_bind_policy'
      )
      result = msis.build_request(:bind_policy,
        effective_date:   policy_application.effective_date,
        payment_plan:     policy_application.billing_strategy.carrier_code,
        installment_day:  policy_application.fields.find{|f| f['title'] == "Installment Day" }&.[]('value') || 1,
        community_id:     community.carrier_profile(5).external_carrier_id,
        unit:             unit.title,
        address:          unit.primary_address,
        maddress:         primary_insured.address || nil,
        primary_insured:    primary_insured,
        additional_insured: additional_insured,
        additional_interest: additional_interest,
        coverage_raw: policy_application.coverage_selections.select{|sel| sel['selection'] }.map do |sel|
          if sel['category'] == 'coverage'
            {
              CoverageCd: sel['uid']
            }.merge(sel['selection'] == true ? {} : {
              Limit: sel['options_format'] == 'percent' ? { Amt: sel['selection'].to_d / 100.to_d } : { Amt: sel['selection'] }
            })
          elsif sel['category'] == 'deductible'
            {
              CoverageCd: sel['uid']
            }.merge(sel['selection'] == true ? {} : {
              Deductible: sel['options_format'] == 'percent' ? { Amt: sel['selection'].to_d / 100.to_d } : { Amt: sel['selection'] }
            })
          else
            nil
          end
        end.compact,
        payment_merchant_id:  payment_merchant_id,
        payment_processor:    payment_processor,
        payment_method:       payment_method,
        payment_info:         payment_params['payment_info'],
        payment_other_id:     payment_params['payment_token'],
        
        line_breaks: true
      )
      if !result
        @bind_response[:message] = "Failed to build bind request (#{msis.errors.to_s})"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
      event.request = msis.compiled_rxml
      event.started = Time.now
      result = msis.call
      event.completed = Time.now
      event.response = result[:data]
      event.status = result[:error] ? 'error' : 'success'
      event.save
      if result[:error]
        @bind_response[:message] = "MSI bind failure (Event ID: #{event.id || event.errors.to_h})\nMSI Error: #{result[:external_message]}\n#{result[:extended_external_message]}"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
      # handle successful bind
      policy_data = result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy")
      @bind_response[:error] = false
      @bind_response[:data][:status] = "SUCCESS"
      @bind_response[:data][:policy_number] = policy_data["PolicyNumber"]
      @bind_response[:data][:policy_prefix] = policy_data["MSI_PolicyPrefix"]
      return @bind_response
    end
    
  end
end
