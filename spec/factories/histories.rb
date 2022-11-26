# == Schema Information
#
# Table name: histories
#
#  id              :bigint           not null, primary key
#  action          :integer          default("create")
#  data            :json
#  recordable_type :string
#  recordable_id   :bigint
#  authorable_type :string
#  authorable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author          :string
#
FactoryBot.define do
  factory :history do
    
  end
end
