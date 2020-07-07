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
end
