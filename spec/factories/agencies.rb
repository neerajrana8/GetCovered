FactoryBot.define do
  factory :agency do
    title { "Get Covered" }
    carriers { [Carrier.first] }
  end
end
