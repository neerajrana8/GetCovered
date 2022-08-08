# == Schema Information
#
# Table name: lease_type_policy_types
#
#  id             :bigint           not null, primary key
#  enabled        :boolean          default(TRUE)
#  lease_type_id  :bigint
#  policy_type_id :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class LeaseTypePolicyType < ApplicationRecord
  belongs_to :lease_type
  belongs_to :policy_type
end
