# == Schema Information
#
# Table name: commission_strategies
#
#  id                     :bigint           not null, primary key
#  title                  :string           not null
#  percentage             :decimal(5, 2)    not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  recipient_type         :string
#  recipient_id           :bigint
#  commission_strategy_id :bigint
#
FactoryBot.define do
  factory :commission_strategy do
    title { 'Get Covered / QBE Residential Commission' }
    carrier { Carrier.first }
  end
end
