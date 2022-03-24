module MasterPolicies
  class YardiBillingJob < ApplicationJob
    queue_as :default

    def perform(*)
=begin
      start_of_last_month = (Time.current.beginning_of_month - 1.day).beginning_of_month.to_date
      mps = Policy.where.not(status: 'CANCELLED').or(Policy.where("cancellation_date >= ?", start_of_last_month))
                  .where("expiration_date >= ?", start_of_last_month)
                  .where(policy_type_id: PolicyType::MASTER_ID)
      mps.each do |mp|
        integration = mp.account.integrations.where(provider: 'yardi').take
        # MOOSE WARNING: erorrr if integration not set up
        mpcs = Policy.where.not(status: 'CANCELLED').or(Policy.where("cancellation_date >= ?", start_of_last_month))
                    .where("expiration_date >= ?", start_of_last_month)
                    .where(policy_type_id: PolicyType::MASTER_COVERAGE_ID, policy: mp)
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
              #### MOOSE WARNING: alert! myseteriously missing config! oh no, Jack! ####
            end
          end
          term_amount = config.term_amount(mpc, start_of_last_month)
          unless term_amount.nil?
            if term_amount == 0
              #### MOOSE WARNING: don't assess a charge ####
            else
              # send charge through yardi
              ###################### make sure mpc.primary_user corresponds to primary lease user!!!
              
              
              
              
              result = Integrations::Yardi::BillingAndPayments::ImportResidentTransactions.run!(integration: integration, charge_hash: {
                Description: "Master Policy...............",
                TransactionDate: start_of_last_month.to_date.to_s,
                ServiceToDate: start_of_last_month.end_of_month.to_date.to_s,
                ChargeCode: mpc.charge_code,
                GLAccountNumber: mpc.integration_account_number,
                CustomerID: ?????????,
                Amount: (term_amount.to_d / 100.to_d).to_s,
                Comment: ???,
                PropertyPrimaryID: ???????
              })
              
              
              
              
              
            end
          end
        end
        
        
        
      end

=end
    end





  end
end
