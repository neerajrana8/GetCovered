class Insurable < ApplicationRecord
  # has_many :insurables
  
  enum category: ['property', 'entity']
  
end
