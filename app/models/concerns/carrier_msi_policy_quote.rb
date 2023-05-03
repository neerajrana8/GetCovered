# =MSI Policy Quote Functions Concern
# file: +app/models/concerns/carrier_msi_policy_quote.rb+

module CarrierMsiPolicyQuote
  extend ActiveSupport::Concern

  included do

    # MOOSE WARNING: PolicyQuote#bind_policy should call this boi if necessary
    def set_msi_external_reference

      return_status = true # MOOSE WARNING: change it?

    end

    # MSI build coverages
    
    def msi_inherited_irc # not actually needed now... left here just in case we reinstate its use
      @msi_inherited_irc ||= ::InsurableRateConfiguration.get_inherited_irc(
        ::CarrierPolicyType.where(carrier_id: MsiService.carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take,
        self.account || self.agency,
        self.policy_application.primary_insurable,
        self.policy_application.effective_date,
        agency: self.agency
      )
    end

    def msi_build_coverages
      self.policy_application.coverage_selections.select{|uid, covsel| covsel['selection'] }.each do |uid, covsel|
        self.policy.policy_coverages.create(
          policy_application: self.policy_application,
          title: covsel['title'],
          designation: uid,
          limit: covsel['category'] != 'coverage' ? 0 : [nil, true].include?(covsel['selection']) ? 0 : covsel['selection']['value'], # MOOSE WARNING: what about percentages?
          deductible: covsel['category'] != 'deductible' ? 0 : [nil, true].include?(covsel['selection']) ? 0 : covsel['selection']['value'], # MOOSE WARNING: what about percentages?
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
      @bind_response = {
        :error => true,
        :message => nil,
        :data => {}
      }
      # handle common failure scenarios
      unless policy_application.carrier_id == 5
        @bind_response[:message] = I18n.t('msi_policy_quote.carrier_must_be_msi')
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
		 	unless accepted? && policy.nil?
		 		@bind_response[:message] = I18n.t('msi_policy_quote.status_must_be_quoted_or_error')
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
		 	end
      # unpack payment info
      payment_data = ((self.carrier_payment_data || {})['payment_methods'] || {})[payment_params['payment_method']]
      if payment_data.nil? || payment_data.class != ::Hash ||
          !payment_data.has_key?('method_id') || !payment_data.has_key?('merchant_id') || !payment_data.has_key?('processor_id') ||
          !payment_params.has_key?('payment_info') || !payment_params.has_key?('payment_token')
        # invalid payment data
        @bind_response[:message] = I18n.t('msi_policy_quote.invalid_payment_data')
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
      payment_merchant_id = payment_data['merchant_id']
      payment_processor = payment_data['processor_id']
      payment_method = payment_data['method_id']
      # grab useful variables
      carrier_agency = CarrierAgency.where(agency: agency, carrier_id: 5).take
      unit = policy_application.primary_insurable
      community = unit.parent_community
      address = unit.primary_address
      primary_insured = policy_application.primary_user
      additional_insured = policy_application.users.select{|u| u.id != primary_insured.id }
      preferred = (unit.get_carrier_status(::MsiService.carrier_id) == :preferred)
      additional_interest = (unit.account ? [unit.account] : msi_additional_interest_array_from_extra_settings(self.policy_application.extra_settings&.[]('additional_interest')))
      # prepare for bind call
      msis = MsiService.new
      result = msis.build_request(:bind_policy,
        effective_date:   policy_application.effective_date,
        payment_plan:     policy_application.billing_strategy.carrier_code,
        installment_day:  (policy_application.extra_settings&.[]('installment_day') || policy_application.fields.find{|f| f['title'] == "Installment Day" }&.[]('value') || 1).to_i,
        community_id:     preferred ? community.carrier_profile(5).external_carrier_id : nil,
        unit:             unit.title,
        address:          unit.primary_address,
        maddress:         primary_insured.address || nil,
        primary_insured:    primary_insured,
        additional_insured: additional_insured,
        additional_interest: additional_interest,
        coverage_raw: policy_application.coverage_selections.select{|uid, sel| sel['selection'] }.map do |uid, sel|
          if sel['category'] == 'coverage'
            {
              CoverageCd: uid
            }.merge(sel['selection'] == true ? {} : {
              Limit: { Amt: sel['selection']['value'].to_d / 100.to_d } # same for percent or currency
            })
          elsif sel['category'] == 'deductible'
            {
              CoverageCd: uid
            }.merge(sel['selection'] == true ? {} : {
              Deductible: { Amt: sel['selection']['value'].to_d / 100.to_d } # same for percent or currency
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
        @bind_response[:message] = "#{I18n.t('msi_policy_quote.failed_to_build_bind_request')} (#{msis.errors.to_s})"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        return @bind_response
      end
      event = events.new(msis.event_params)
      event.request = msis.compiled_rxml
      event.started = Time.now
      result = msis.call
      event.completed = Time.now
      event.response = result[:response].response.body
      event.status = result[:error] ? 'error' : 'success'
      event.save
      if result[:error]
        @bind_response[:message] = "#{I18n.t('msi_policy_quote.msi_bind_failure')} #{event.id || event.errors.to_h})\n#{I18n.t('msi_policy_quote.msi_error')} #{result[:external_message]}\n#{result[:extended_external_message]}"
        #PolicyBindWarningNotificationJob.perform_later(message: @bind_response[:message])
        @bind_response[:client_message] = I18n.t('msi_policy_quote.invalid_pm_email') if event.response&.index("An email address is required for the Additional Interest included within the XML request.")
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

    def msi_additional_interest_array_from_extra_settings(hash)
      return [] if hash.blank?
      case hash['entity_type']
        when 'company'
          pseudoname = [hash['company_name'][0...50], hash['company_name'][50...(hash['company_name'].length)]]
          if !(pseudoname.first.blank? && pseudoname.first.blank?) && pseudoname.first.blank? != pseudoname.second.blank?
            psn = (pseudoname.first || '') + (pseudoname.second || '').strip
            splitter = [psn.index(' ') || 50, (psn.length.to_f/2).ceil, 50].min
            pseudoname = [psn[0...splitter], psn[splitter...psn.length]]
            pseudoname[1] = "EndOfCompanyName" if pseudoname[1].blank?
          end
          addr = hash['address']
          gotten_email = hash['email_address']
          gotten_phone = hash['phone_number']
          if gotten_phone.blank?
            gotten_phone = nil
          else
            gotten_phone = gotten_phone.delete("^0-9")
            gotten_phone = gotten_phone[-10..-1] if gotten_phone.length > 10
            gotten_phone = nil if gotten_phone.length < 10
          end
          return [{
            NameInfo: {
              PersonName: {
                GivenName: pseudoname.first,
                Surname:   pseudoname.last
              }.merge(addr.nil? ? {} : { OtherGivenName: addr })
            },
            Communications: { # feel free to add phone number here just like we do for user#get_msi_general_party_info
              EmailInfo: {
                EmailAddr: gotten_email
              }
            }.merge(gotten_phone.nil? ? {} : {
              PhoneInfo: {
                PhoneNumber: gotten_phone
              }
            })
          }]
        when 'person'
          gotten_email = hash['email_address']
          gotten_phone = hash['phone_number']
          if gotten_phone.blank?
            gotten_phone = nil
          else
            gotten_phone = gotten_phone.delete("^0-9")
            gotten_phone = gotten_phone[-10..-1] if gotten_phone.length > 10
            gotten_phone = nil if gotten_phone.length < 10
          end
          return [{
            NameInfo: {
              PersonName: {
                GivenName: hash['first_name'],
                Surname:   hash['last_name']
              }.merge(hash['middle_name'].blank? ? {} : { OtherGivenName: hash['middle_name'] })
            },
            Communications: {
              PhoneInfo: {
                PhoneNumber: gotten_phone
              },
              EmailInfo: {
                EmailAddr: gotten_email
              }
            }
          }]
      end
      return []
    end

  end
end
