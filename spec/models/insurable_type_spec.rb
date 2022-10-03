# frozen_string_literal: true

# == Schema Information
#
# Table name: insurable_types
#
#  id              :bigint           not null, primary key
#  title           :string
#  slug            :string
#  category        :integer
#  enabled         :boolean
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  policy_type_ids :bigint           default([]), not null, is an Array
#  occupiable      :boolean          default(FALSE)
#
RSpec.describe InsurableType, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
