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
##
# =Policy Application Field Model
# file: +app/models/policy_application_field.rb+

class PolicyApplicationField < ApplicationRecord
	
  belongs_to :policy_type
  belongs_to :carrier
  belongs_to :policy_application_field, optional: true
  
  has_many :policy_application_answers
  has_many :policy_application_fields

  accepts_nested_attributes_for :policy_application_fields
  
  enum section: { fields: 0, questions: 1 }
  enum answer_type: { BOOLEAN: 0, STRING: 1, NUMBER: 2, DATE: 3, OPTION_SELECT: 4 }
 
end
