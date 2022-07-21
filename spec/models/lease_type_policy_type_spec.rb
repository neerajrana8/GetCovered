# frozen_string_literal: true

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
RSpec.describe LeaseTypePolicyType, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
