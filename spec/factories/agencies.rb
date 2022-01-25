FactoryBot.define do
  factory :agency do
    title { 'Get Covered' }
    carriers { [Carrier.first] }
    # after(:create) do |agency|
    #   agency.global_permission = FactoryBot.create(:global_permission, :for_agency, ownerable: agency)
    # end
  end

  factory :sub_agency, class: Agency do |parent_id|
    title { 'Sub Get Covered' }
    carriers { [Carrier.first] }
    agency_id { parent_id }
    after(:create) do |agency|
      agency.global_agency_permission ||= FactoryBot.build(:global_agency_permission, agency: agency)
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
