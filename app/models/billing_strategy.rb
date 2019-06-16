class BillingStrategy < ApplicationRecord
  belongs_to :agency
  belongs_to :carrier
  belongs_to :policy_type
end
