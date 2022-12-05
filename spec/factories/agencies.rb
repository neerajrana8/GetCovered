# == Schema Information
#
# Table name: agencies
#
#  id                      :bigint           not null, primary key
#  title                   :string
#  slug                    :string
#  call_sign               :string
#  enabled                 :boolean          default(FALSE), not null
#  whitelabel              :boolean          default(FALSE), not null
#  tos_accepted            :boolean          default(FALSE), not null
#  tos_accepted_at         :datetime
#  tos_acceptance_ip       :string
#  verified                :boolean          default(FALSE), not null
#  stripe_id               :string
#  master_agency           :boolean          default(FALSE), not null
#  contact_info            :jsonb
#  settings                :jsonb
#  agency_id               :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  staff_id                :bigint
#  integration_designation :string
#  producer_code           :string
#  carrier_preferences     :jsonb            not null
#
FactoryBot.define do
  factory :agency do
    title { 'Get Covered' }
    carriers { [Carrier.find(1), Carrier.find(5)] }
    after(:create) do |agency|
      agency.global_permission = FactoryBot.create(:global_permission, ownerable: agency)
    end
  end

  factory :sub_agency, class: Agency do
    title { 'Sub Get Covered' }
    carriers { [Carrier.find(1), Carrier.find(5)] }
    after(:create) do |agency|
      agency.global_permission = FactoryBot.create(:global_permission, ownerable: agency, permissions: agency.parent_agency.global_permission.permissions)
    end
  end

  factory :random_agency, class: Agency do
    title { Faker::Name.name }
    carriers { [Carrier.last] }
    after(:create) do |agency|
      agency.global_agency_permission ||= FactoryBot.build(:global_agency_permission, agency: agency)
    end
  end
end
