FactoryBot.define do
  factory :commission_strategy do
    title { 'Get Covered / QBE Residential Commission' }
    carrier { Carrier.first }
  end
end
