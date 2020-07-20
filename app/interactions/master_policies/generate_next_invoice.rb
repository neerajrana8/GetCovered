module MasterPolicies
  class GenerateNextInvoice < ActiveInteraction::Base
    object :master_policy, class: Policy

    def execute
      coverages = master_policy.policies.where('effective_date < ? AND expiration_date >= ?', 1.month.ago, Time.zone.now).count
      amount = master_policy.policy_premiums.take.base
      Invoice.create!(
        due_date: Time.zone.now + 7.day,
        available_date: Time.zone.now,
        term_first_date: 1.month.ago,
        term_last_date: Time.zone.now,
        invoiceable: master_policy,
        payer: master_policy.account,
        status: 'quoted',
  
        total: amount * coverages,
        line_items_attributes: [
          {
            title: 'Premium',
            price: amount * coverages,
            refundability: 'no_refund',
            category: 'uncategorized'
          }
        ]
      )
    end

    private
  end
end
