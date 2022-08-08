# == Schema Information
#
# Table name: policy_groups
#
#  id                     :bigint           not null, primary key
#  number                 :string
#  effective_date         :date
#  expiration_date        :date
#  auto_renew             :boolean          default(FALSE), not null
#  last_renewed_on        :date
#  renew_count            :integer
#  billing_status         :integer
#  billing_dispute_count  :integer
#  billing_behind_since   :date
#  cancellation_code      :integer
#  cancellation_date_date :string
#  status                 :integer
#  status_changed_on      :datetime
#  billing_dispute_status :integer
#  billing_enabled        :boolean          default(FALSE), not null
#  system_purchased       :boolean          default(FALSE), not null
#  serviceable            :boolean          default(FALSE), not null
#  has_outstanding_refund :boolean          default(FALSE), not null
#  system_data            :jsonb
#  last_payment_date      :date
#  next_payment_date      :date
#  policy_in_system       :boolean
#  auto_pay               :boolean
#  agency_id              :bigint
#  account_id             :bigint
#  carrier_id             :bigint
#  policy_type_id         :bigint
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class PolicyGroup < ApplicationRecord
  has_many :policies
  has_many :policy_group_quotes
  has_many :invoices, through: :policy_group_quotes
  has_one :policy_application
  has_one :policy_group_premium

  has_one :policy_application_group
  belongs_to :agency
  belongs_to :account, optional: true
  belongs_to :carrier
  belongs_to :policy_type
  
  scope :current, -> { where(status: %i[BOUND BOUND_WITH_WARNING]) }
  scope :policy_in_system, ->(policy_in_system) { where(policy_in_system: policy_in_system) }
  scope :unpaid, -> { where(billing_status: ['BEHIND', 'REJECTED']) }

end
