# =DC Policy Quote Functions Concern
# file: +app/models/concerns/carrier_dc_policy_quote.rb+

module CarrierDcPolicyQuote
  extend ActiveSupport::Concern

  included do

    def set_dc_external_reference
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
      dcs.build_request(:insured,
        address_id: unit_cip.data["dc_address_id"],
        unit_id: unit_cip.external_carrier_id,
        first_name: policy_application.primary_user.profile.first_name,
        last_name: policy_application.primary_user.profile.last_name,
        email: policy_application.primary_user.email,
        payment_token: payment_params['payment_token']
      )
      event = events.new(
        verb: DepositChoiceService::HTTP_VERB_DICTIONARY[:rate].to_s,
        format: 'json',
        interface: 'REST',
        endpoint: dcs.endpoint_for(:insured),
        process: 'deposit_choice_insured'
      )
      event.request = dcs.message_content
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:response].response.body
      event.status = result[:error] ? 'error' : 'success'
      event.save
      # make sure we succeeded
      if result[:error] || result[:data]["insuredId"].blank?
		 		@bind_response[:message] = "Bond Creation Failed: Deposit Choice service rejected user information"
        return @bind_response
      end
      # grab variables
      insured_id = result[:data]["insuredId"]
      # perform bind call
      result = dcs.build_request(:binder,
        insured_id: insured_id,
        address_id: unit_cip.data["dc_address_id"],
        unit_id: unit_cip.external_carrier_id,
        move_in_date: policy_application.effective_date,
        primary_occupant: policy_application.primary_user.get_deposit_choice_occupant_hash(primary: true),
        additional_occupants: policy_application.policy_users.where(primary: false).map do |pu|
          pu.user.get_deposit_choice_occupant_hash(primary: false)
        end,
        bond_amount: (policy_application.coverage_selections["bondAmount"].to_d / 100.to_d).to_s,
        rated_premium: (policy_application.coverage_selections["ratedPremium"].to_d / 100.to_d).to_s,
        processing_fee: (policy_application.coverage_selections["processingFee"].to_d / 100.to_d).to_s
      )
      if !result
        @bind_response[:message] = "Failed to build bind request (#{dcs.errors.to_s})"
        return @bind_response
      end
      event = events.new(
        verb: 'post',
        format: 'xml',
        interface: 'REST',
        endpoint: dcs.endpoint_for(:binder),
        process: 'deposit_choice_binder'
      )
      event.request = dcs.message_content
      event.started = Time.now
      result = dcs.call
      event.completed = Time.now
      event.response = result[:data].response.body
      event.status = result[:error] ? 'error' : 'success'
      event.save
      if result[:error]
        @bind_response[:message] = "Deposit Choice bind failure (Event ID: #{event.id || event.errors.to_h})\nMSI Error: #{result[:external_message]}\n#{result[:extended_external_message]}"
        return @bind_response
      end
      # handle successful bind
      @bind_response[:error] = false
      @bind_response[:data][:status] = "SUCCESS"
      @bind_response[:data][:policy_number] = result[:data]["policyNumber"]
      @bind_response[:data][:bond_certificate] = result[:data]["bondCertificate"] # but what do we do with this...?
      return @bind_response
      return @bind_response
    end
    
  end
end
