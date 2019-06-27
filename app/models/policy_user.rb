class PolicyUser < ApplicationRecord
  belongs_to :policy_application, optional: true
  belongs_to :policy, optional: true
  belongs_to :user, optional: true
end
