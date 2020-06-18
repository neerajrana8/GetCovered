class InsurableGeographicalCategory < ApplicationRecord
  extend ArrayEnum
  
  # ActiveRecord Callbacks
  
  before_validation :set_counties_nil_if_empty
  
  before_validation :normalize_counties
  
  # Validations
  
  validate :nonempty_counties_implies_nonempty_state
  
  # Constants & Enums
  
  US_STATE_CODES = { AK: 0, AL: 1, AR: 2, AZ: 3, CA: 4, CO: 5, CT: 6, 
                DC: 7, DE: 8, FL: 9, GA: 10, HI: 11, IA: 12, ID: 13, 
                IL: 14, IN: 15, KS: 16, KY: 17, LA: 18, MA: 19, MD: 20, 
                ME: 21, MI: 22, MN: 23, MO: 24, MS: 25, MT: 26, NC: 27, 
                ND: 28, NE: 29, NH: 30, NJ: 31, NM: 32, NV: 33, NY: 34, 
                OH: 35, OK: 36, OR: 37, PA: 38, RI: 39, SC: 40, SD: 41, 
                TN: 42, TX: 43, UT: 44, VA: 45, VT: 46, WA: 47, WI: 48, 
                WV: 49, WY: 50 } # WARNING: this should always match the state codes in Address (use a concern?)

  enum state: US_STATE_CODES
  
  # Methods
  
  def self.get_for(state, counties = nil, save_on_create: true)
    query = InsurableGeographicalCategory.where(state: state)
    if counties.blank?
      counties = nil
      query = query.where(counties: nil)
    else
      counties = counties.map{|c| c.upcase }.sort!.uniq!
      query = query.where('counties = ARRAY[?]::string[]', counties)
    end
    to_return = query.take
    if to_return.nil?
      to_return = InsurableGeographicalCategory.new(state: state, counties: counties)
      to_return.save if save_on_create
    end
    return to_return
  end
  
  # Sorts them from most general to most specific;
  # sorting an array of IGCs will ensure that if one contains another,
  # the other is later in the list; addresses will always be last in the list
  def <=>(other)
    if self.state.nil? || other.state.nil?
      if self.state.nil? && other.state.nil?
        0
      else
        self.state.nil? ? -1 : 1
      end
    else
      if self.state != other.state
        self.state <=> other.state
      else
        if self.counties.nil? || other.counties.nil?
          if self.counties.nil? && other.counties.nil?
            0
          else
            self.counties.nil? ? -1 : 1
          end
        else
          self.counties.size <=> other.counties.size
        end
      end
    end
  end

  private
  
    def set_counties_nil_if_empty
      self.counties = nil if self.counties.blank?
    end
    
    def normalize_counties
      self.counties.map!{|cty| cty.upcase }.sort!.uniq! unless self.counties.nil?
    end
  
    def nonempty_counties_implies_nonempty_state
      errors.add(:state, "cannot be blank if counties are specified") if !self.counties.blank? && state.nil?
    end
    
end
