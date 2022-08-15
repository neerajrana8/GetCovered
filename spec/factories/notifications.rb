# == Schema Information
#
# Table name: notifications
#
#  id              :bigint           not null, primary key
#  subject         :string
#  message         :text
#  status          :integer          default("undelivered")
#  delivery_method :integer          default("push")
#  code            :integer          default("success")
#  action          :integer          default("community_rates_sync")
#  template        :integer          default("default")
#  notifiable_type :string
#  notifiable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
FactoryBot.define do
  factory :notification do
    
  end
end
