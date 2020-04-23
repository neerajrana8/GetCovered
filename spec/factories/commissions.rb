FactoryBot.define do
  factory :commission do
    amount { 1000 }
    approved { false }
    paid { false }
    distributes { nil }
    association :commissionable, factory: :agency
  end
end