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
