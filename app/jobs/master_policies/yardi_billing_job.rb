module MasterPolicies
  class YardiBillingJob < ApplicationJob
    queue_as :default

    def perform
=begin
      start_of_last_month = (Time.current.beginning_of_month - 1.day).beginning_of_month.to_date
      mps = Policy.where.not(status: 'CANCELLED').or(Policy.where("cancellation_date >= ?", start_of_last_month))
                  .where("expiration_date >= ?", start_of_last_month)
                  .where(policy_type_id: PolicyType::MASTER_ID)
                  .order(id: :asc)
      mps.each do |mp|
        integration = mp.account.integrations.where(provider: 'yardi').take
        # MOOSE WARNING: erorrr if integration not set up
        mpcs = Policy.where.not(status: 'CANCELLED').or(Policy.where("cancellation_date >= ?", start_of_last_month))
                    .where("expiration_date >= ?", start_of_last_month)
                    .where(policy_type_id: PolicyType::MASTER_COVERAGE_ID, policy: mp)
                    .order(id: :asc)
        # set up map from insurable to yardi profiles
        integration_profiles = integration.integration_profiles.where(profileable_id: (mp.insurables.map{|i| i.id } + mp.insurables.map{|i| i.insurable_id }).compact, external_context: 'community')
        integration_profiles = mp.insurables.map{|ins| [ins.id, yardi_property_ids.find{|ip| ip.profileable_id == ins.id } || yardi_property_ids.find{|ip| ip.profileable_id == ins.insurable_id } ] }.to_h
        # set up map from MP coverage to MP configuration
        configs = mp.insurables.map{|ins| [ins.id, mp.find_closest_master_policy_configuration(ins)] }.to_h
        Insurable.where(insurable_id: configs.keys, insurable_type_id: InsurableType::RESIDENTIAL_BUILDINGS_IDS).where.not(id: configs.keys).each do |bldg|
          configs[bldg.id] = configs[bldg.insurable_id]
        end
        mpc_id_to_config = PolicyInsurable.references(:insurables).includes(:insurable).where(policy: mpcs).group_by{|pi| pi.policy_id }.transform_values{|v| configs[v.first.insurable_id] }
        # send off charges
        mpcs.each do |mpc|
          config = mpc_id_to_config[mpc.id]
          if config.nil?
            config = mp.find_closest_master_policy_configuration(mpc.primary_insurable) # try to do it the direct way (which would be less query-efficient to do for all records when avoidable)
            if config.nil?
              #### MOOSE WARNING: alert! mysteriously missing config! oh no, Jack! ####
            end
          end
          term_amount = config.term_amount(mpc, start_of_last_month)
          charge_description = ????????????????????????????????????????????????????????????????????? # MOOSE WARNING
          unless term_amount.nil?
            if term_amount == 0
              ::Invoice.create!(
                available_date: start_of_last_month.end_of_month + 1.day,
                due_date: start_of_last_month.end_of_month + 1.day,
                external: true,
                status: "managed_externally",
                invoiceable: mpc,
                payer: mpc.primary_user,
                collector: integration,
                line_items: [
                  ::LineItem.new(
                    chargeable: mpc,
                    title: charge_description,
                    original_total_due: term_amount,
                    analytics_category: 'other',
                    policy: mpc
                  )
                ]
              )
            else
              # set up invoice to log errors
              invoice = ::Invoice.new(
                available_date: start_of_last_month.end_of_month + 1.day,
                due_date: start_of_last_month.end_of_month + 1.day,
                external: true,
                status: "managed_externally",
                invoiceable: mpc,
                payer: mpc.primary_user,
                collector: integration,
                line_items: [
                  ::LineItem.new(
                    chargeable: mpc,
                    title: charge_description,
                    original_total_due: term_amount,
                    analytics_category: 'other',
                    policy: mpc
                  )
                ]
              )
              # send charge through yardi
              yardi_property_id = integration_profiles[mpc.primary_insurable.insurable_id]&.external_id
              yardi_customer_id = mpc.primary_user&.integration_profiles&.where(integration: integration)&.take&.external_id
              if yardi_property_id.nil? || yardi_customer_id.nil?
                #### moose warning: FREAK OUT, WE CAN'T DO IT
              end
              result = Integrations::Yardi::BillingAndPayments::ImportResidentTransactions.run!(integration: integration, charge_hash: {
                Description: "Master Policy Fee", # MOOSE WARNING: retitle???
                TransactionDate: Time.current.to_date.to_s,
                ServiceToDate: (start_of_last_month + 1.month).to_s,
                ChargeCode: mpc.charge_code,
                GLAccountNumber: mpc.integration_account_number,
                CustomerID: yardi_customer_id,
                Amount: (term_amount.to_d / 100.to_d).to_s,
                Comment: "", # do we want something like the following? "Get Covered Master Policy ##{mp.number}, Coverage ##{mpc.number}, #{Date::MONTHNAMES[start_of_last_month.month]} #{start_of_last_month.year}",
                PropertyPrimaryID: yardi_property_id
              })
              unless result[:success]
                # error code returned by yardi
                invoice.under_review = true
                invoice.error_info = [{
                  description: "Attempt to export charge to Yardi resulted in an error response.",
                  time: Time.current.to_s,
                  amount: term_amount,
                  event_id: result[:event]&.id,
                  parsed_response: result[:parsed_response]
                }]
              else
                result_message = result[:parsed_response]&.dig('Envelope', 'Body', 'ImportResidentTransactions_LoginResponse', 'ImportResidentTransactions_LoginResult', 'Messages', 'Message')
                if result_message.class != ::String || !result.include?("charges were successfully imported")
                  # no error code but weird error with yardi attempt
                  invoice.under_review = true
                  invoice.error_info = [{
                    description: "Attempt to export charge to Yardi resulted in an unknown error.",
                    time: Time.current.to_s,
                    amount: term_amount,
                    event_id: result[:event]&.id,
                    parsed_response: result[:parsed_response]
                  }]
                else
                  # success
                  # no need to touch the invoice
                end
              end
              invoice.save
              
              
              
              
            end # end if term_amount == 0
          end # end unless term_amount.nil?
        end # end mpcs.each
      end # end mps.each
=end
    end # end perform()
  end # end class YardiBillingJob
end # end module
