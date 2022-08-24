# frozen_string_literal: true

# == Schema Information
#
# Table name: lease_type_insurable_types
#
#  id                :bigint           not null, primary key
#  enabled           :boolean          default(TRUE)
#  lease_type_id     :bigint
#  insurable_type_id :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
RSpec.describe LeaseTypeInsurableType, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
