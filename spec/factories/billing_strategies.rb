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
