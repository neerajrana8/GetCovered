class ArchivedCommissionDeduction < ApplicationRecord
  belongs_to :policy
  belongs_to :deductee, polymorphic: true
end
