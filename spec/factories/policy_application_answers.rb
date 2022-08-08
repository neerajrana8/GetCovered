# == Schema Information
#
# Table name: policy_application_answers
#
#  id                          :bigint           not null, primary key
#  data                        :jsonb
#  section                     :integer          default("fields"), not null
#  policy_application_field_id :bigint
#  policy_application_id       :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
FactoryBot.define do
  factory :policy_application_answer do
    policy_application
    policy_application_field
  end
end
