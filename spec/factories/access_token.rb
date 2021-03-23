FactoryBot.define do
  factory :access_token do
    bearer_type { "Agency" }
    #bearer_id { FactoryBot.create(:random_agency).id }
    enabled { true }
    access_type { "agency_integration" }
  end
end
