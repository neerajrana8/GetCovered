class PolicyGroup < ApplicationRecord
  has_many :policies
  has_many :invoices, as: :invoiceable
  has_one :policy_application

  has_one :policy_application_group
  belongs_to :agency
  belongs_to :account, optional: true
  belongs_to :carrier
  belongs_to :policy_type
end
