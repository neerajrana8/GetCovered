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
