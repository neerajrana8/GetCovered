# == Schema Information
#
# Table name: policy_users
#
#  id                    :bigint           not null, primary key
#  primary               :boolean          default(FALSE), not null
#  spouse                :boolean          default(FALSE), not null
#  policy_application_id :bigint
#  policy_id             :bigint
#  user_id               :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  status                :integer          default("invited")
#  disputed_at           :datetime
#  dispute_status        :integer          default("undisputed")
#  dispute_reason        :text
#
FactoryBot.define do
  factory :policy_user do
    primary { true }
    association :user, factory: :user
  end

  factory :policy_user_with_account, class: PolicyUser do
    primary { true }
    status { "accepted" }
    association :user, factory: :user

    trait :set_account_user do
      true
    end

    trait :set_first_as_primary do
      primary { true }
      status { "accepted" }
    end
  end
end
