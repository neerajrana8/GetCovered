# == Schema Information
#
# Table name: addresses
#
#  id               :bigint           not null, primary key
#  street_number    :string
#  street_name      :string
#  street_two       :string
#  city             :string
#  state            :integer
#  county           :string
#  zip_code         :string
#  plus_four        :string
#  country          :string
#  full             :string
#  full_searchable  :string
#  latitude         :float
#  longitude        :float
#  timezone         :string
#  primary          :boolean          default(FALSE), not null
#  addressable_type :string
#  addressable_id   :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  searchable       :boolean          default(FALSE)
#  neighborhood     :string
#
FactoryBot.define do
  factory :address do
    state { "MA" }
    street_number { 34 }
    street_name { "Allston Rd" }
    city { 'Boston' }
    zip_code { '02215' }
  end
end
