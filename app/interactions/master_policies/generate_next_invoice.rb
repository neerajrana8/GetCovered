module MasterPolicies
  class GenerateNextInvoice < ActiveInteraction::Base
    object :master_policy, class: Policy
    time :range_start, default: 1.month.ago
    time :range_end,   default: Time.zone.now

    def execute
      Invoice.create!(
        due_date: Time.zone.now + 1.day,
        available_date: Time.zone.now,
        term_first_date: range_start,
        term_last_date: range_end,
        invoiceable: master_policy,
        payer: master_policy.account,
        status: 'available',

        total: amount * coverages.count,
        line_items_attributes: line_items_attributes
      )
    end

    private

    def line_items_attributes
      coverages.map do |coverage|
        {
          title: coverage.number,
          price: amount,
          refundability: 'no_refund',
          category: 'uncategorized'
        }
      end
    end

    def coverages
      @coverages ||=
        master_policy.policies.where(coverages_condition, range_start: range_start, range_end: range_end)
    end

    def coverages_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end) 
        OR (expiration_date > :range_start AND expiration_date < :range_end) 
        OR (effective_date >= :range_start AND effective_date < :range_end)
        OR (effective_date < :range_start AND expiration_date >= :range_end)
      SQL
    end

    def amount
      @amount ||= master_policy.policy_premiums.take.base
    end
  end
end
