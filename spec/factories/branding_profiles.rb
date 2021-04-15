FactoryBot.define do
  factory :branding_profile do
    subdomain { "" }
    sequence(:url) { |n| "getcovered+#{n}.com" }
    logo_url { "some_url.com" }
    footer_logo_url { "some_url.com" }
    association :profileable, factory: :agency

    trait :default_branding_profile do
      profileable { Agency.find_by_id(Agency::GET_COVERED_ID) || FactoryBot.create(:agency)}
    end
  end
end
