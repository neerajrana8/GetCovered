# == Schema Information
#
# Table name: staffs
#
#  id                     :bigint           not null, primary key
#  provider               :string           default("email"), not null
#  uid                    :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  allow_password_change  :boolean          default(FALSE)
#  remember_created_at    :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#  email                  :string
#  enabled                :boolean          default(FALSE), not null
#  settings               :jsonb
#  notification_options   :jsonb
#  owner                  :boolean          default(FALSE), not null
#  organizable_type       :string
#  organizable_id         :bigint
#  tokens                 :json
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invitation_token       :string
#  invitation_created_at  :datetime
#  invitation_sent_at     :datetime
#  invitation_accepted_at :datetime
#  invitation_limit       :integer
#  invited_by_type        :string
#  invited_by_id          :bigint
#  invitations_count      :integer          default(0)
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string
#  last_sign_in_ip        :string
#  role                   :integer          default("staff")
#
FactoryBot.define do
  factory :staff do
    sequence(:email) { |n| "test#{n}@test.com" }
    enabled { true }
    password { 'test1234' }
    password_confirmation { 'test1234' }
    association :profile, factory: :profile
    organizable do
      case role
      when 'agent'
        FactoryBot.create(:agency)
      when 'staff'
        FactoryBot.create(:account)
      end
    end

    after(:create) do |staff|
      staff.staff_permission ||= FactoryBot.create(:staff_permission, staff: staff) if staff.organizable.is_a?(Agency)
    end
  end
end
