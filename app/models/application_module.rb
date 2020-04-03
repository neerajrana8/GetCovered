class ApplicationModule < ApplicationRecord
  
  include SetSlug
  
  # Validations
  
  validates_presence_of :title, :slug

end
