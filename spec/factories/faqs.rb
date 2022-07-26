# == Schema Information
#
# Table name: faqs
#
#  id                  :bigint           not null, primary key
#  title               :string
#  branding_profile_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  faq_order           :integer          default(0)
#  language            :integer          default("en")
#
FactoryBot.define do
  factory :faq do
    title { "" }
    branding_profile_id { BrandingProfile.first }
  end
end
