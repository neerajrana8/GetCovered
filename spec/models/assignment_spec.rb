# frozen_string_literal: true

# == Schema Information
#
# Table name: assignments
#
#  id              :bigint           not null, primary key
#  primary         :boolean
#  staff_id        :bigint
#  assignable_type :string
#  assignable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
RSpec.describe Assignment, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
