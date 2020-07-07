FactoryBot.define do
  factory :faq do
    title { "" }
    branding_profile_id { BrandingProfile.first }
  end
end
