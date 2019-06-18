class PolicyQuote < ApplicationRecord
  belongs_to :policy_application
  belongs_to :agency
  belongs_to :account
  belongs_to :policy
end
