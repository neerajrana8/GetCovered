# frozen_string_literal: true

# == Schema Information
#
# Table name: users
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
#  email                  :citext
#  enabled                :boolean          default(FALSE), not null
#  settings               :jsonb
#  notification_options   :jsonb
#  owner                  :boolean          default(FALSE), not null
#  user_in_system         :boolean
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
#  stripe_id              :string
#  payment_methods        :jsonb
#  current_payment_method :integer
#  mailchimp_id           :string
#  mailchimp_category     :integer          default("prospect")
#  qbe_id                 :string
#  has_existing_policies  :boolean          default(FALSE)
#  has_current_leases     :boolean          default(FALSE)
#  has_leases             :boolean          default(FALSE)
#  altuid                 :string
#
RSpec.describe User, elasticsearch: true, type: :model do
  pending "#{__FILE__} Needs to be updated after removing elasticsearch tests"
end
