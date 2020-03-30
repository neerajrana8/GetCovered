FactoryBot.define do
  factory :branding_profile do
    title { "Get Covered" }
    subdomain { "os" }
    url { "getcovered.com" }
    logo_url { "some_url.com" }
    footer_logo_url { "some_url.com" }
    association :profileable, factory: :agency
  end
end