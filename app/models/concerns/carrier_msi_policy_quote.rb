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
      self.policy_application.coverage_selections.select{|covsel| covsel['selection'] != false }.each do |covsel|
        self.policy.policy_coverages.create(
          policy_application: self.policy_application,
          title: covsel['title'],
          designation: covsel['uid'],
          schedule: covsel['category'],
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
        PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
		 	unless accepted? && policy.nil?
		 		@bind_response[:message] = "Status must be quoted or error to bind quote"
        PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
		 	end
      # unpack payment info
      payment_data = ((self.carrier_payment_data || {})['payment_methods'] || {})[payment_params['payment_method']]
      if payment_data.nil? || payment_data.class != ::Hash ||
          !payment_data.has_key?('method_id') || !payment_data.has_key?('merchant_id') || !payment_data.has_key?('processor_id') ||
          !payment_params.has_key?('payment_info') || !payment_params.has_key?('payment_token')
        # invalid payment data
        @bind_response[:message] = "Invalid payment data for binding policy"
        PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
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
      # prepare for bind call
      msis = MsiService.new
      event = events.new(
        verb: 'post',
        format: 'xml',
        interface: 'REST',
        endpoint: msi_service.endpoint_for(:bind_policy),
        process: 'msi_bind_policy'
      )
      result = msis.build_request(:bind_policy,
        effective_date:   policy_application.effective_date,
        payment_plan:     policy_application.billing_strategy.carrier_code,
        installment_day:  [28, Time.current.to_date.day].min, # WARNING: or do we prefer to always set it to 1?
        community_id:     community.carrier_profile(5).external_carrier_id,
        unit:             unit.title,
        address:          unit.primary_address,
        # MOOSE WARNING: mailing address!
        primary_insured:    primary_insured,
        additional_insured: additional_insured,
        additional_interest: [], # MOOSE WARNING: put the Account here somehow!!!!!!
        coverage_DEBUG: (coverages + deductibles),
        
        payment_merchant_id:  payment_merchant_id,
        payment_processor:    payment_processor,
        payment_method:       payment_method,
        payment_info:         payment_params['payment_info'],
        payment_other_id:     payment_params['payment_token'],
        
        line_breaks: true
      )
      if !result
        @bind_response[:message] = "Failed to build bind request (#{msis.errors.to_s})"
        PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
      event.started = Time.now
      result = msis.call
      event.completed = Time.now
      event.response = result[:data]
      event.status = result[:error] ? 'error' : 'success'
      event.save
      if result[:error]
        @bind_response[:message] = "MSI bind failure (Event ID: #{event.id})\nMSI Error: #{result[:external_message]}\n#{result[:extended_external_message]}"
        PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
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
