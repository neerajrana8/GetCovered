# =MSI Policy Quote Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierMsiPolicyQuote
  extend ActiveSupport::Concern

  included do

    # MOOSE WARNING: PolicyQuote#bind_policy should call this boi if necessary
    def set_msi_external_reference
      
      return_status = true # MOOSE WARNING: change it? 
      
    end
    
    # MSI build coverages
    
    def msi_build_coverages
      self.policy_application.coverage_selections.select{|covsel| covsel['selection'] }.each do |covsel|
        self.policy.policy_coverages.create(
          policy_application: self.policy_application,
          title: covsel['title'],
          designation: covsel['uid'],
          limit: covsel['category'] != 'coverage' ? 0 : [nil, true].include?(covsel['selection']) ? 0 : covsel['selection'].to_i,
          deductible: covsel['category'] != 'deductible' ? 0 : [nil, true].include?(covsel['selection']) ? 0 : covsel['selection'].to_i,
          enabled: true
        )
      end
    end
    
    # MSI Bind
  
    # payment_params should be a hash of form:
    #   {
    #     'payment_method' => 'card' or 'ach',
    #     'payment_info'   => msi format hash of card/bank info,
    #     'payment_token'  => the token
    #   }
    def msi_bind(payment_params)
      # MOOSE WARNING: modify qbe bind methods here
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}  
      }
      # handle common failure scenarios
      unless policy_application.carrier_id == 5
        @bind_response[:message] = "Carrier must be QBE to bind residential quote"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
		 	unless accepted? && policy.nil?
		 		@bind_response[:message] = "Status must be quoted or error to bind quote"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
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
      # determine preferred status
      preferred = !(community.carrier_profile(5)&.external_carrier_id.nil?)
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
        installment_day:  policy_application.extra_settings&.[]('installment_day') || policy_application.fields.find{|f| f['title'] == "Installment Day" }&.[]('value') || 1,
        community_id:     preferred ? community.carrier_profile(5).external_carrier_id : nil,
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
        # for non-preferred
        **(preferred ? {} : {
          number_of_units: policy_application.extra_settings&.[]('number_of_units'),
          years_professionally_managed: policy_application.extra_settings&.[]('years_professionally_managed'),
          year_built: policy_application.extra_settings&.[]('year_built'),
          gated: policy_application.extra_settings&.[]('gated')
        }.compact),
        # format params
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
      event.response = result[:response].response.body
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
