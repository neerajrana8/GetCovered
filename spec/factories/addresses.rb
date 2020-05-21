FactoryBot.define do
  factory :address do
    state { "MA" }
    street_number { 34 }
    street_name { "Allston Rd" }
    city { 'Boston' }
    zip_code { '02215' }
  end
end