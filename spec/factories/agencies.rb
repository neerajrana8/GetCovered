FactoryBot.define do
  factory :agency do
    title { "Get Covered" }
    carriers { [Carrier.first] }
  end

  factory :sub_agency, class: Agency do |parent_id|
    title { "Sub Get Covered" }
    carriers { [Carrier.first] }
    agency_id { parent_id }
  end
end
