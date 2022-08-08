# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id             :bigint           not null, primary key
#  verb           :integer          default("get")
#  format         :integer          default("json")
#  interface      :integer          default("REST")
#  status         :integer          default("in_progress")
#  process        :string
#  endpoint       :string
#  started        :datetime
#  completed      :datetime
#  request        :text
#  response       :text
#  eventable_type :string
#  eventable_id   :bigint
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
RSpec.describe Event, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
