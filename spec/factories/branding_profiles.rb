FactoryBot.define do
  factory :branding_profile do
    title { "GetCovered" }
    subdomain { "" }
    sequence(:url) { |n| "getcovered+#{n}.com" }
    logo_url { "some_url.com" }
    footer_logo_url { "some_url.com" }
    association :profileable, factory: :agency
  end
end
