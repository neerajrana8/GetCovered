# == Schema Information
#
# Table name: payment_profiles
#
#  id              :bigint           not null, primary key
#  source_id       :string
#  source_type     :integer
#  fingerprint     :string
#  default_profile :boolean          default(FALSE)
#  active          :boolean
#  verified        :boolean
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  payer_type      :string
#  payer_id        :bigint
#  card            :jsonb
#
FactoryBot.define do
  factory :payment_profile do
    source_id { "MyString" }
    source_type { 0 }
    default { nil }
    active { false }
  end
end
