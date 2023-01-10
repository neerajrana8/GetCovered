class CoverageRequirement < ApplicationRecord
  belongs_to :insurable, optional: true
  belongs_to :account, optional: true
end
