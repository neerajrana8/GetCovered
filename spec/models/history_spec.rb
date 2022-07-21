# frozen_string_literal: true

# == Schema Information
#
# Table name: histories
#
#  id              :bigint           not null, primary key
#  action          :integer          default("create")
#  data            :json
#  recordable_type :string
#  recordable_id   :bigint
#  authorable_type :string
#  authorable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  author          :string
#
RSpec.describe History, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
