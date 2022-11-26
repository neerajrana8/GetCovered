# == Schema Information
#
# Table name: branding_profiles
#
#  id                     :bigint           not null, primary key
#  url                    :string
#  default                :boolean          default(FALSE), not null
#  styles                 :jsonb
#  profileable_type       :string
#  profileable_id         :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  logo_url               :string
#  footer_logo_url        :string
#  subdomain              :string
#  global_default         :boolean          default(FALSE), not null
#  logo_jpeg_url          :string
#  enabled                :boolean          default(TRUE)
#  second_logo_url        :string
#  second_footer_logo_url :string
#
FactoryBot.define do
  factory :branding_profile do
    subdomain { "" }
    sequence(:url) { |n| "getcovered+#{n}.com" }
    logo_url { "some_url.com" }
    footer_logo_url { "some_url.com" }
    association :profileable, factory: :agency

    trait :default_branding_profile do
      profileable { Agency.find_by_id(Agency::GET_COVERED_ID) || FactoryBot.create(:agency, id: Agency::GET_COVERED_ID )}
    end
  end
end
