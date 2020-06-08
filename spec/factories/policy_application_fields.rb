FactoryBot.define do
  factory :policy_application_field do
    carrier { Carrier.first }
    policy_type { carrier.policy_types.take }
  end
end
