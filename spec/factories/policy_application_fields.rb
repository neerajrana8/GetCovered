# == Schema Information
#
# Table name: policy_application_fields
#
#  id                          :bigint           not null, primary key
#  title                       :string
#  section                     :integer
#  answer_type                 :integer
#  default_answer              :string
#  desired_answer              :string
#  answer_options              :jsonb
#  enabled                     :boolean
#  order_position              :integer
#  policy_application_field_id :bigint
#  policy_type_id              :bigint
#  carrier_id                  :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
FactoryBot.define do
  factory :policy_application_field do
    carrier { Carrier.first }
    policy_type { carrier.policy_types.take }
  end
end
