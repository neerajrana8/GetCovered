# Address model
# file: +app/models/address.rb+

class Address < ApplicationRecord
  
  geocoded_by :full
    
  before_save :set_full,
              :set_full_searchable,
              :convert_region

  after_validation :geocode
    
  belongs_to :addressable, 
    polymorphic: true,
    required: false
    
  # Address.full_street_address
  # Returns full street address of Address from available variables
  def full_street_address
    [combined_street_address(), street_two, 
     combined_locality_region(), combined_postal_code(), 
     country].compact
             .join(', ')
             .gsub(/\s+/, ' ')
             .strip
  end
  
  def set_full
    self.full = full_street_address()  
  end
  
  def set_full_searchable
    self.full_searchable = [combined_street_address(), street_two, 
                            combined_locality_region(), 
                            combined_postal_code(), 
                            country].compact
                                    .join(' ')
                                    .gsub(/\s+/, ' ')
                                    .strip
  end
  
  def combined_street_address
    [street_number, street_name].compact
                               .join(' ')
                               .gsub(/\s+/, ' ')
                               .strip  
  end

  def combined_postal_code
    return plus_four.nil? ? zip_code : "#{zip_code}-#{plus_four}"
  end
  
  def combined_locality_region
    return "#{city} #{state}"  
  end    
end
