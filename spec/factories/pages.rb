# == Schema Information
#
# Table name: pages
#
#  id                  :bigint           not null, primary key
#  content             :text
#  title               :string
#  agency_id           :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  branding_profile_id :bigint
#  styles              :jsonb
#
FactoryBot.define do
  factory :page do
    
  end
end
