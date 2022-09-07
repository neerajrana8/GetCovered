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
FactoryBot.define do
  factory :event do
    
  end
end
