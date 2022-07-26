# == Schema Information
#
# Table name: accounts
#
#  id                        :bigint           not null, primary key
#  title                     :string
#  slug                      :string
#  call_sign                 :string
#  enabled                   :boolean          default(FALSE), not null
#  whitelabel                :boolean          default(FALSE), not null
#  tos_accepted              :boolean          default(FALSE), not null
#  tos_accepted_at           :datetime
#  tos_acceptance_ip         :string
#  verified                  :boolean          default(FALSE), not null
#  stripe_id                 :string
#  contact_info              :jsonb
#  settings                  :jsonb
#  staff_id                  :bigint
#  agency_id                 :bigint
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  payment_profile_stripe_id :string
#  current_payment_method    :integer
#  additional_interest       :boolean          default(TRUE)
#  minimum_liability         :integer
#
FactoryBot.define do
  factory :account do
    title { "Get Covered account" }
    agency
  end
end
