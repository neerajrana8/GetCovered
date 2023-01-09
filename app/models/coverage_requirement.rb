class CoverageRequirement < ApplicationRecord
  belongs_to :insurable
  belongs_to :account
end
