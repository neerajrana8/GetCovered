module Reports
  class BordereauJob < ApplicationJob
    queue_as :default

    def perform()
      range_start = 1.month.ago
      range_end = Time.zone.now
      Reports::BordereauCreate.run!(range_start: range_start, range_end: range_end)
    end

    private

    def master_policies
      Policy.where(policy_type_id: PolicyType::MASTER_IDS)
    end
  end
end
