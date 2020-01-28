##
# =Policy Coverages Model
# file: +app/models/policy_coverages.rb+

class PolicyCoverage < ApplicationRecord

  belongs_to :policy, optional: true
  belongs_to :policy_application, optional: true
  
  scope :coverage_type, ->(type) { where("designation = ?", type) }
end
