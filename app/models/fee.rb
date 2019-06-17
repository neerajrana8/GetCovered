class Fee < ApplicationRecord
  
  # Turn off single table inheritance
  self.inheritance_column = :_type_disabled
  
  belongs_to :assignable, polymorphic: true
  belongs_to :ownerable, polymorphic: true


end
