# == Schema Information
#
# Table name: billing_strategies
#
#  id             :bigint           not null, primary key
#  title          :string
#  slug           :string
#  enabled        :boolean          default(FALSE), not null
#  new_business   :jsonb
#  renewal        :jsonb
#  locked         :boolean          default(FALSE), not null
#  agency_id      :bigint
#  carrier_id     :bigint
#  policy_type_id :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  carrier_code   :string
#
FactoryBot.define do
  factory :monthly_billing_strategy, class: "BillingStrategy" do
    title { "Monthly" }
    enabled { true }
    new_business { { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09],
  		                                                      payments_per_term: 12, remainder_added_to_deposit: true } }
    renewal { { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33],
  		                                                      payments_per_term: 12, remainder_added_to_deposit: true } }
    carrier_code { "QBE_MoRe" }
  end

  factory :monthly_billing_strategy_with_carrier, class: "BillingStrategy" do
    title { "Monthly" }
    enabled { true }
    new_business { { payments: [22.01, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09, 7.09],
                     payments_per_term: 12, remainder_added_to_deposit: true } }
    renewal { { payments: [8.37, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33, 8.33],
                payments_per_term: 12, remainder_added_to_deposit: true } }
    carrier { Carrier.last }
    policy_type { PolicyType.first }
  end
end
