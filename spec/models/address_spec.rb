# frozen_string_literal: true

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
RSpec.describe Address, elasticsearch: true, type: :model do
  pending "#{__FILE__} Needs to be updated after removing elasticsearch tests"
end
