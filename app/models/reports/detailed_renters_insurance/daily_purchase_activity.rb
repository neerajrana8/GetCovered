module Reports
  class DailyPurchaseActivity < ::Report
    NAME = 'DailyPurchaseActivity'.freeze

    def generate
      if reportable.is_a?(Agency)
        policies = reportable.policies.where(created_at: range_start..range_start)
        policies.each do |policy|
          addr = policy.primary_user.address.nil? ? nil : policy.primary_user.address.full
          prem = policy.policy_premiums.count > 0 ? '%.2f' % (policy.policy_premiums.first.total.to_f / 100) : nil
          self.data["rows"] << [policy.number, policy.created_at.strftime("%B %-d, %Y"),
                                policy.effective_date.strftime("%B %-d, %Y"),
                                policy.expiration_date.strftime("%B %-d, %Y"),
                                prem,
                                policy.policy_type.title,
                                policy.status.titlecase,
                                policy.primary_user.profile.full_name,
                                policy.primary_user.email,
                                addr,
                                policy.users.count]
        end
      end
      self
    end

    private

    def set_defaults
      self.data ||= {}
      self.data["rows"] ||= []
    end
  end
end
