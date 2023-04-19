require 'fileutils'
require 'nokogiri'
module CarrierQBE
  class CreatePolicyJob < ApplicationJob
    queue_as :default
    def perform(file_name)
      create_policy(file_name)
    end
  
    def transaction_translation(code: nil)
      return_value = nil
      case code
      when 'N'
        # Do nothing
        return_value = 'New Business'
      when 'W'
        # Call Hanna's Function
        return_value = 'Renewal'
      when 'P'
        # Do Nothing
        return_value = 'Pending Cancellation'
      when 'X'
        # Do Nothing
        return_value = 'Rescind Cancellation'
      when 'C'
        # Cancel Policy
        return_value = 'Cancellation'
      when 'R'
        # Do Nothing
        return_value = 'Reinstatement'
      when 'E'
        # Check Policy Coverages for Changes
        return_value = 'Endorsement'
      when 'L'
        # Do Nothing
        return_value = 'Claim Activity'
      end
    end
  
    def create_policy(file_name)
      file_path = "#{Rails.root}/public/ftp_cp/#{file_name}"
  
      doc = File.open(file_path) { |f| Nokogiri::XML(f) }
      insurance_service_requests = doc.xpath('//InsuranceSvcRs')
      @output = []
      insurance_service_requests.each do |isr|
        for_output = {
  
          coverages: [],
  
          users: []
  
        }
  
        transaction = isr.xpath('.//TransactionType').map(&:text)[0]
  
        producer = isr.xpath('.//Producer//ProducerInfo//ContractNumber').text
        agency = CarrierAgency.exists?(external_carrier_id: producer) ? CarrierAgency.where(external_carrier_id: producer).first.agency : Agency.find(1)
  
        policy_data = isr.xpath('.//PersPolicy')
  
        number = policy_data.xpath('.//PolicyNumber').text.sub(/^.../, '')
        premium = policy_data.xpath('.//CurrentTermAmt//Amt').text.to_i * 100
        dates = policy_data.xpath('.//ContractTerm')
        start_date_arr = dates.xpath('.//EffectiveDt').text.split('/').reject(&:empty?).map(&:to_i)
  
        start_date = Date.new(start_date_arr[2], start_date_arr[0], start_date_arr[1])
  
        expiration_date_arr = dates.xpath('.//ExpirationDt').text.split('/').reject(&:empty?).map(&:to_i)
  
        expiration_date = Date.new(expiration_date_arr[2], expiration_date_arr[0], expiration_date_arr[1])
  
        home_line_data = isr.xpath('.//HomeLineBusiness')
  
        home_line_data.xpath('.//Coverage').each do |coverage_record|
          for_output[:coverages] << {
  
            code: coverage_record.xpath('.//CoverageCd').map(&:text)[0],
  
            limit: coverage_record.xpath('.//Limit//FormatInteger').text.to_i * 100
          }
        end
        if Policy.exists?(number: number)
  
          for_output[:policy_exists] = true
        else
          for_output[:policy_exists] = false
          policy = Policy.new(
            carrier_id: 1,
  
            policy_type_id: 1,
  
            agency: agency,
  
            number: number,
  
            effective_date: start_date,
  
            expiration_date: expiration_date,
  
            status: 'BOUND',
  
            policy_in_system: true
          )
  
          if policy.save
            isr.xpath('.//InsuredOrPrincipal').each do |insured_or_principal|
              first_name = insured_or_principal.xpath('.//PersonName//GivenName').text.strip.titlecase
              last_name = insured_or_principal.xpath('.//PersonName//Surname').text.strip.titlecase
              birth_date_arr = insured_or_principal.xpath('.//PersonInfo//BirthDt').text.split('/').reject(&:empty?).map(&:to_i)
  
              birth_date = Date.new(birth_date_arr[2], birth_date_arr[0], birth_date_arr[1])
  
              primary = insured_or_principal.xpath('.//InsuredOrPrincipalInfo//InsuredOrPrincipalRoleCd').text
              for_output[:users] << {
  
                name: "#{first_name} #{last_name}".strip!,
  
                primary: primary == 'Insured'
              }
  
              user = User.create(email: "#{first_name}#{last_name}@xyz.com", password: 'Test1234!', password_confirmation: 'Test1234!',
  
                                 profile_attributes: { first_name: first_name, last_name: last_name, birth_date: birth_date })
  
              PolicyUser.create(primary: primary == 'Insured', policy: policy, user: user)
              pq = PolicyQuote.create( reference: "DT-HTRXFWIJOTWY",
                                  external_reference: nil,
                                  status: "accepted",
                                  status_updated_on: DateTime.now,
                                  policy_application_id: PolicyApplication.first,
                                  agency_id: Agency.first.id,
                                  account_id: Account.first.id,
                                  policy_id: policy.id,
                                  est_premium: 21700,
                                  external_id: nil,
                                  policy_group_quote_id: nil,
                                  carrier_payment_data: {"policy_fee"=>2500})
              policy_premium = PolicyPremium.create(total_premium: 42_000,
                                                    total_fee: 0,
                                                    total_tax: 0,
                                                    total: 42_000,
                                                    prorated: true,
                                                    prorated_last_moment: DateTime.now,
                                                    prorated_first_moment: DateTime.now,
                                                    force_no_refunds: false,
                                                    error_info: nil,
                                                    policy_quote_id: pq.id,
                                                    policy_id: policy.id,
                                                    commission_strategy_id: 26,
                                                    archived_policy_premium_id: 3,
                                                    total_hidden_fee: 0,
                                                    total_hidden_tax: 0)
              PolicyPremiumItem.create(title: 'premium',
                                                          category: 'premium',
                                                          rounding_error_distribution: 'first_payment_simple',
                                                          original_total_due: 54_895,
                                                          total_due: 54_895,
                                                          total_received: 0,
                                                          proration_pending: false,
                                                          proration_calculation: 'per_payment_term',
                                                          proration_refunds_allowed: true,
                                                          commission_calculation: 'as_received',
                                                          commission_creation_delay_hours: nil,
                                                          policy_premium_id: policy_premium.id,
                                                          collection_plan_type: nil,
                                                          collection_plan_id: nil,
                                                          fee_id: nil,
                                                          recipient_type: 'Carrier',
                                                          recipient_id: 1,
                                                          collector_type: 'Agency',
                                                          collector_id: 1,
                                                          hidden: false)

            end
          else
            for_output[:policy_saved] = false
            pp policy.errors
          end
          for_output[:policy_valid_with_current_data] = policy.valid?
        end
        for_output[:transaction] = transaction
        a = 1
        for_output[:transaction_reason] = transaction_translation(code: transaction)
        a = 1
        for_output[:policy_number] = number
        for_output[:effective_date] = start_date
        for_output[:expiration_date] = expiration_date
        for_output[:premium] = premium
        @output << for_output
      end
    end
  end
end
