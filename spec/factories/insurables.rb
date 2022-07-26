# == Schema Information
#
# Table name: insurables
#
#  id                       :bigint           not null, primary key
#  title                    :string
#  slug                     :string
#  enabled                  :boolean          default(FALSE)
#  account_id               :bigint
#  insurable_type_id        :bigint
#  insurable_id             :bigint
#  category                 :integer          default("property")
#  covered                  :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  agency_id                :bigint
#  policy_type_ids          :bigint           default([]), not null, is an Array
#  preferred_ho4            :boolean          default(FALSE), not null
#  confirmed                :boolean          default(TRUE), not null
#  occupied                 :boolean          default(FALSE)
#  expanded_covered         :jsonb            not null
#  preferred                :jsonb
#  additional_interest      :boolean          default(FALSE)
#  additional_interest_name :string
#  minimum_liability        :integer
#
FactoryBot.define do
  factory :insurable do
    sequence :title, &:to_s
    association :account, factory: :account
    enabled { true }
    residential_unit

    trait :residential_community do
      insurable_type_id { InsurableType::RESIDENTIAL_COMMUNITIES_IDS.first }
    end

    trait :residential_unit do
      insurable_type_id { InsurableType::RESIDENTIAL_UNITS_IDS.first }
    end

    trait :building do
      insurable_type_id { InsurableType::BUILDINGS_IDS.first }
    end
  end
end
