# == Schema Information
#
# Table name: claims
#
#  id            :bigint           not null, primary key
#  subject       :string
#  description   :text
#  time_of_loss  :datetime
#  status        :integer          default("pending")
#  claimant_type :string
#  claimant_id   :bigint
#  insurable_id  :bigint
#  policy_id     :bigint
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  type_of_loss  :integer          default("OTHER"), not null
#  staff_notes   :text
#
FactoryBot.define do
  factory :claim do
    
  end
end
