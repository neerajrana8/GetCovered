# == Schema Information
#
# Table name: insurable_rates
#
#  id              :bigint           not null, primary key
#  title           :string
#  schedule        :string
#  sub_schedule    :string
#  description     :text
#  liability_only  :boolean
#  number_insured  :integer
#  deductibles     :jsonb
#  coverage_limits :jsonb
#  interval        :integer          default("month")
#  premium         :integer          default(0)
#  activated       :boolean
#  activated_on    :date
#  deactivated_on  :date
#  paid_in_full    :boolean
#  carrier_id      :bigint
#  agency_id       :bigint
#  insurable_id    :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  enabled         :boolean          default(TRUE)
#  mandatory       :boolean          default(FALSE)
#
FactoryBot.define do
  factory :insurable_rate do
    
  end
end
