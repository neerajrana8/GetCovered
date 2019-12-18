# Address model
# file: +app/models/address.rb+

class Address < ApplicationRecord

  include ElasticsearchSearchable

  geocoded_by :full
    
  before_save :set_full,
              :set_full_searchable,
              :from_full

	before_create :set_first_as_primary

  after_validation :geocode
    
  belongs_to :addressable, 
    polymorphic: true,
    required: false

  enum state: { AK: 0, AL: 1, AR: 2, AZ: 3, CA: 4, CO: 5, CT: 6, 
                DC: 7, DE: 8, FL: 9, GA: 10, HI: 11, IA: 12, ID: 13, 
                IL: 14, IN: 15, KS: 16, KY: 17, LA: 18, MA: 19, MD: 20, 
                ME: 21, MI: 22, MN: 23, MO: 24, MS: 25, MT: 26, NC: 27, 
                ND: 28, NE: 29, NH: 30, NJ: 31, NM: 32, NV: 33, NY: 34, 
                OH: 35, OK: 36, OR: 37, PA: 38, RI: 39, SC: 40, SD: 41, 
                TN: 42, TX: 43, UT: 44, VA: 45, VT: 46, WA: 47, WI: 48, 
                WV: 49, WY: 50 }
  
  # scope :residential_communities, -> { joins(:insurable).where() }
  
  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :street_number, type: :text, analyzer: 'english'
      indexes :street_name, type: :text, analyzer: 'english'
      indexes :street_two, type: :text, analyzer: 'english'
      indexes :city, type: :text, analyzer: 'english'
      indexes :state, type: :text, analyzer: 'english'
      indexes :county, type: :text, analyzer: 'english'
      indexes :zip_code, type: :text, analyzer: 'english'
      indexes :plus_four, type: :text, analyzer: 'english'
      indexes :full, type: :text, analyzer: 'english'
      indexes :full_searchable, type: :text, analyzer: 'english'
      indexes :addressable_type, type: :text, analyzer: 'english'
#       indexes :location, type: 'geo_point'
      indexes :timezone, type: :text, analyzer: 'english'
      indexes :primary, type: :boolean
      indexes :created_at, type: :date
      indexes :updated_at, type: :date
    end
  end

  def as_indexed_json(options={})
    as_json(options).merge location: { lat: latitude, lon: longitude }
  end

  # Address.full_street_address
  # Returns full street address of Address from available variables
  def full_street_address
    [combined_street_address(), street_two, 
     combined_locality_region(), combined_zip_code()].compact
             .join(', ')
             .gsub(/\s+/, ' ')
             .strip
  end
  
  # Address.set_full
  # Sets full field with the result of full_street_address()
  def set_full
    self.full = full_street_address()  
  end
 
  # Address.from_full
  # Attempts to fill out nil fields in street address by using StreetAddress gem
  def from_full
    street_address = { 
      street_number: street_number,
      street_name: street_name,
      street_two: street_two,
      city: city,
      state: state,
      zip_code: zip_code,
      plus_four: plus_four 
    }
    
    if street_address.values.any?(nil) &&
       !full.nil?
      parsed_address = StreetAddress::US.parse(full)
      unless parsed_address.nil?
        street_address.keys.each do |key|
          if self.send(key).nil?
            key_string = key.to_s
            case key_string
            when 'street_number'
              self.street_number = parsed_address.number
              self.street_name = "#{ parsed_address.prefix } #{ parsed_address.street } #{ parsed_address.suffix } #{ parsed_address.street_type }".gsub(/\s+/, ' ').strip
            when 'street_name'
              self.street_name = "#{ parsed_address.prefix } #{ parsed_address.street } #{ parsed_address.suffix } #{ parsed_address.street_type }".gsub(/\s+/, ' ').strip
            when 'street_two'
              self.street_two = !parsed_address.unit.nil? || !parsed_address.unit_prefix.nil? ? "#{ parsed_address.unit_prefix } #{ parsed_address.unit }".gsub(/\s+/, ' ').strip : nil
            when 'city'
              self.city = parsed_address.city
            when 'state'
              self.state = parsed_address.city
            when 'zip_code'
              self.zip_code = parsed_address.postal_code
            when 'plus_four'
              self.plus_four = parsed_address.postal_code_ext
            end
          end
        end
      end
    end
  end
  
  # Address.set_full_searchable
  # Sets full_searchable field with the full street address minus any punctuation
  def set_full_searchable
    self.full_searchable = [combined_street_address(), street_two, 
                            combined_locality_region(), 
                            combined_zip_code()].compact
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

  def combined_zip_code
    return plus_four.nil? ? zip_code : "#{zip_code}-#{plus_four}"
  end
  
  def combined_locality_region
    return "#{city}, #{state}"  
  end 
  
  def set_first_as_primary
		unless addressable.nil?
			self.primary = true if self.addressable.respond_to?("addresses") && self.addressable.addresses.count == 0
		end  
	end

	def self.search_insurables(query)
	  self.search({
	    query: {
	      bool: {
	        must: [
	        {
	          multi_match: {
	            query: query,
	            fields: [:full, :full_searchable]
	          }
	        },
	        {
	          match: {
	            addressable_type: "Insurable"
	          }
	        }]
	      }
	    }
	  })
	end
      
end
