FactoryBot.define do
  factory :payment_profile do
    source_id { "MyString" }
    source_type { 0 }
    default { nil }
    active { false }
  end
end
