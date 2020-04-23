class PolicyGroup < ApplicationRecord
  has_many :policies

  belongs_to :agency
  belongs_to :account, optional: true
  belongs_to :carrier
  belongs_to :policy_type
end
