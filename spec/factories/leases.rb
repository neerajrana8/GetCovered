# == Schema Information
#
# Table name: leases
#
#  id               :bigint           not null, primary key
#  reference        :string
#  start_date       :date
#  end_date         :date
#  status           :integer          default("pending")
#  covered          :boolean          default(FALSE)
#  lease_type_id    :bigint
#  insurable_id     :bigint
#  account_id       :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  expanded_covered :jsonb
#  defunct          :boolean          default(FALSE), not null
#
FactoryBot.define do
  factory :lease do
    association :account, factory: :account
    association :insurable, factory: :insurable
    lease_type { LeaseType.find_by_title('Residential') }
    status { :current }
    start_date { 10.day.ago }
    end_date { Time.now }
  end
end
