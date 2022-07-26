# == Schema Information
#
# Table name: policy_coverages
#
#  id                      :bigint           not null, primary key
#  title                   :string
#  designation             :string
#  limit                   :integer          default(0)
#  deductible              :integer          default(0)
#  policy_id               :bigint
#  policy_application_id   :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  enabled                 :boolean          default(FALSE), not null
#  special_deductible      :integer
#  occurrence_limit        :integer
#  is_carrier_fee          :boolean          default(FALSE)
#  aggregate_limit         :integer
#  external_payments_limit :integer
#  limit_used              :integer
#
##
# =Policy Coverages Model
# file: +app/models/policy_coverages.rb+

class PolicyCoverage < ApplicationRecord

  belongs_to :policy, optional: true
  belongs_to :policy_application, optional: true
  
  scope :coverage_type, ->(type) { where("designation = ?", type) }
end
