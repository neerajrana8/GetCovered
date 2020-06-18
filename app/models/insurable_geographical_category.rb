class InsurableGeographicalCategory < ApplicationRecord
  extend ArrayEnum
  
  # ActiveRecord Callbacks
  
  before_validation :set_counties_nil_if_empty
  
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
  
    def nonempty_counties_implies_nonempty_state
      errors.add(:state, "cannot be blank if counties are specified") if !self.counties.blank? && state.nil?
    end
  
  
  
  
  
  
  
  
  
=begin
  def get_parents(mutable: nil)
    to_return = generic_superset_query(
      case mutable
        when true 
          InsurableGeographicalCategory.where(configurer_type: configurer_type, configurer_id: configurer_id)
        when false
          case configurer_type
            when 'Account'
              InsurableGeographicalCategory.where(configurer_type: 'Agency', configurer_id: configurer.agency_id)
                .or(InsurableGeographicalCategory.where(configurer_type: 'Carrier', configurer_id: carrier_insurable_type.carrier_id))
            when 'Agency'
              InsurableGeographicalCategory.where(configurer_type: 'Carrier', configurer_id: carrier_insurable_type.carrier_id)
            when 'Carrier'
              InsurableGeographicalCategory.where("TRUE = FALSE")
            else # should never run
              InsurableGeographicalCategory.where("TRUE = FALSE")
          end
        when nil
          case configurer_type
            when 'Account'
              InsurableGeographicalCategory.where(configurer_type: 'Agency', configurer_id: configurer.agency_id)
                .or(InsurableGeographicalCategory.where(configurer_type: 'Carrier', configurer_id: carrier_insurable_type.carrier_id))
                .or(InsurableGeographicalCategory.where(configurer_type: configurer_type, configurer_id: configurer_id)
            when 'Agency'
              InsurableGeographicalCategory.where(configurer_type: 'Carrier', configurer_id: carrier_insurable_type.carrier_id)
                .or(InsurableGeographicalCategory.where(configurer_type: configurer_type, configurer_id: configurer_id)
            when 'Carrier'
              InsurableGeographicalCategory.where(configurer_type: configurer_type, configurer_id: configurer_id)
            else # should never run
              InsurableGeographicalCategory.where(configurer_type: configurer_type, configurer_id: configurer_id)
          end
        else # should never run
          InsurableGeographicalCategory.where(configurer_type: configurer_type, configurer_id: configurer_id)
      end
    )
    return to_return
  end

  def <=>(other)
    return CONFIGURER_MODELS[configurer_type] - CONFIGURER_MODELS[other.configurer_type] unless configurer_type == other.configurer_type
    return 0
  end
  
  def contains?(other)
    [:state,:county,:zip_code,:city].all?{|prop| other.send(prop).nil? || (self.send(prop) - other.send(prop)).blank? }
  end
  
  def arrange_for_inheritance(to_arrange, candidates: [])
    
  end
=end
  
=begin
  def arrange_for_inheritance(to_arrange, candidates: [])
    to_arrange.each do |x|
      
    end
  end
  
  
  
  def arrange_for_inheritance(list)
    arrangement = []
    cur_level = arrangement
    to_insert = list.map{|x| x }
    old_inserters = list
    
    to_insert.each do |x|
      container = cur_level.find{|y| y[0].contains?(x) }
      if container.nil?
        # create a new entry & move any contained entries into it
        container = [x]
        contained_indices = cur_level.map.with_index{|y,i| x.contains?(y[0]) ? i : nil }.compact
        unless contained_indices.length == 0
          contained_indices.each{|i| container.push(cur_level[i]); cur_level[i] = nil }
          cur_level.compact!
        end
      else
        # add us to the entry that contains us
        container.push(x)
      end
    end
    
  end
=end
  
  private
  
    #def generic_superset_query(starting_query = InsurableGeographicalCategory.all)
    #  starting_query
    #    .where(state: nil).or(starting_query.where(state: state))
    #    .where('county IS NULL OR county @> ARRAY[?]::string[]', county)
    #    .where(carrier_insurable_type_id: carrier_insurable_type_id)
    #end
    
end
