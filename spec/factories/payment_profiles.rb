FactoryBot.define do
  factory :payment_profile do
    source_id { "MyString" }
    source_type { 0 }
    fingerprint { "MyString" }
    default { false }
    active { false }
    user { nil }
  end
end
