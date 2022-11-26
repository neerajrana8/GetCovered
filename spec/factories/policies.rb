# == Schema Information
#
# Table name: policies
#
#  id                           :bigint           not null, primary key
#  number                       :string
#  effective_date               :date
#  expiration_date              :date
#  auto_renew                   :boolean          default(FALSE), not null
#  last_renewed_on              :date
#  renew_count                  :integer
#  billing_status               :integer
#  billing_dispute_count        :integer          default(0), not null
#  billing_behind_since         :date
#  status                       :integer
#  status_changed_on            :datetime
#  billing_dispute_status       :integer          default("UNDISPUTED"), not null
#  billing_enabled              :boolean          default(FALSE), not null
#  system_purchased             :boolean          default(FALSE), not null
#  serviceable                  :boolean          default(FALSE), not null
#  has_outstanding_refund       :boolean          default(FALSE), not null
#  system_data                  :jsonb
#  agency_id                    :bigint
#  account_id                   :bigint
#  carrier_id                   :bigint
#  policy_type_id               :bigint
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  policy_in_system             :boolean
#  auto_pay                     :boolean
#  last_payment_date            :date
#  next_payment_date            :date
#  policy_group_id              :bigint
#  declined                     :boolean
#  address                      :string
#  out_of_system_carrier_title  :string
#  policy_id                    :bigint
#  cancellation_reason          :integer
#  branding_profile_id          :integer
#  marked_for_cancellation      :boolean          default(FALSE), not null
#  marked_for_cancellation_info :string
#  marked_cancellation_time     :datetime
#  marked_cancellation_reason   :string
#  document_status              :integer          default("absent")
#  force_placed                 :boolean
#  cancellation_date            :date
#
FactoryBot.define do
  factory :policy do
    expiration_date { 1.year.from_now }
    effective_date { 1.day.ago }
    carrier_id { 1 }
    sequence(:number) { |n| "bfd55#{n}fgbd" }
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type_id { 1 }

    trait :master do
      policy_type_id { PolicyType::MASTER_ID }
    end

    trait :master_coverage do
      policy_type_id { PolicyType::MASTER_COVERAGE_ID }
    end
  end

  factory :policy_with_user_account, class: Policy do
    expiration_date { 1.year.from_now }
    effective_date { 2.day.ago }
    carrier { Carrier.last }
    sequence(:number) { |n| "add55#{n}fgvv" }
    agency
    account { FactoryBot.create(:account, agency: agency) }
    policy_type { carrier.policy_types.take }
    policy_users { [FactoryBot.create(:policy_user_with_account)] }

  end
end
