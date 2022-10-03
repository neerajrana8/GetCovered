# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  duration        :integer
#  range_start     :datetime
#  range_end       :datetime
#  data            :jsonb
#  reportable_type :string
#  reportable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  type            :string
#
module Reports
  class DailyPurchaseActivity < ::Report
    NAME = 'DailyPurchaseActivity'.freeze

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << self.data["headers"]
        self.data["rows"].each do |row|
          csv << row
        end
      end
    end

    def generate_csv
      document_title = "#{ reportable.title }-Daily-Report-#{ range_start.strftime('%B %-d %Y') }.csv".downcase
                           .gsub(' ', '-')
      save_path = Rails.root.join('tmp', document_title)

      File.open(save_path, 'wb') do |file|
        file << to_csv()
      end

      return save_path
    end

    def generate
      if reportable.is_a?(Agency)
        policies = reportable.policies.where(created_at: range_start..range_end)

        policies.each do |policy|
          addr = policy.primary_user.address.nil? ? nil : policy.primary_user.address.full
          prem = policy.policy_premiums.count > 0 ? '%.2f' % (policy.policy_premiums.first.total.to_f / 100) : nil
          self.data["rows"] << [policy.number,
                                policy.created_at.strftime("%B %-d, %Y"),
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
      self.data["headers"] ||= ["#",
                                 "Purchased",
                                 "Effective",
                                 "Expiration",
                                 "Premium",
                                 "Policy Type",
                                 "Policy Status",
                                 "Primary Insured Name",
                                 "Primary Insured Email",
                                 "Primary Insured Address",
                                 "Insured Count"]
    end
  end
end
