class Insurable < ApplicationRecord
  # Concerns
  include CarrierQbeCommunity, EarningsReport, RecordChange
  
  enum category: ['property', 'entity']
  
end
