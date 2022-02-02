class InsurableGeographicalCategory < ApplicationRecord

  # Associations

  has_many :insurable_rate_configurations,
    as: :configurable
  belongs_to :insurable,  # used to associate a sample insurable with each QBE region, for rate caching
    optional: true

  # ActiveRecord Callbacks

  before_validation :normalize_data

  # Validations

  validate :nonempty_substate_data_implies_nonempty_state

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
  enum special_usage: ['qbe_ho4']
  
  VARCHAR_ARRAYS = ['counties', 'zip_codes', 'cities'] # this gives the list of fields of type varchar array; an IGC represents all regions which are (1) in the given state and (2) for each non-empty varchar array, are in one of the listed locations
  
  # class methods
  
  def self.normalize_string(dat_crazy_strang)
    dat_crazy_strang.gsub(/^[a-z]/, " ").strip.upcase.chomp(" COUNTY")
  end

  def self.normalize_zip(meesa_bein_a_zippy_strang)
    to_return = meesa_bein_a_zippy_strang.split('-')[0].gsub(/^[0-9]/, '')
    to_return = "#{ (0...(to_return.length - 5)).map{ '0' }.join('') }#{to_return}"
    return to_return
  end
  
  class <<self # we create normalization method aliases here for all the varchar array fields
    VARCHAR_ARRAYS.each do |vca|
      alias_method "normalize_#{vca}_entry".to_sym, vca == 'zip_codes' ? :normalize_zip : :normalize_string
    end
  end

  def self.get_for(state:, save_on_create: true, counties: nil, zip_codes: nil, cities: nil)
    query = InsurableGeographicalCategory.where(state: state)
    props = VARCHAR_ARRAYS.map{|prop| [prop, eval(prop)] }.to_h.map do |prop, vals|
      new_vals = nil
      unless vals.blank?
        new_vals = vals.map{|v| self.send("normalize_#{prop}_entry", v) }
        new_vals.uniq!
        new_vals.sort!
        query = query.where("#{prop} = ARRAY[?]::varchar[]", new_vals)
      end
      [prop, new_vals]
    end.to_h
    to_return = query.take
    if to_return.nil?
      to_return = InsurableGeographicalCategory.new(props.merge({ state: state }))
      to_return.save if save_on_create
    end
    return to_return
  end
  
  # instance methods
  
  def query_for_parents(include_self: true)
    to_return = ::InsurableGeographicalCategory.where(state: nil)
    unless self.state.nil?
      to_return = to_return.or(
        VARCHAR_ARRAYS.inject(::InsurableGeographicalCategory.all) do |query, prop|
          query.merge(
            ::InsurableGeographicalCategory.where({ prop.to_sym => nil }).send(*(self.send(prop).blank? ? [:itself] : [:or,
              ::InsurableGeographicalCategory.where("#{prop} @> ARRAY[?]::varchar[]", self.send(prop))
            ]))
          )
        end.where(state: self.state)
      )
    end
    to_return = to_return.where.not(id: self.id) if !include_self && !self.id.nil?
    return to_return
  end
  
  def query_for_children(include_self: true)
    to_return = ::InsurableGeographicalCategory.all
    to_return = to_return.where(state: self.state) unless self.state.nil?
    VARCHAR_ARRAYS.each{|prop| next if self.send(prop).blank?; to_return = to_return.where("#{prop} <@ ARRAY[?]::varchar[]", self.send(prop)) }
    to_return = to_return.where.not(id: self.id) if !include_self && !self.id.nil?
    return to_return
  end


  # returns an array for use in sorting IGCs; sorting IGCs lexicographically by IGC.norm will provide a total order which ensures supersets are > their subsets
  def norm
    # the first entry ensures we sort by state, with a countrywide (nil state) igc always coming first; beyond that,
    # since when state is the same igc1 is a subset of igc2 iff all of igc1's varchar arrays are subsets of the corresponding arrays in igc2 (where a nil varchar array counts as "everything"),
    # a given IGC essentially represents the set of points in VARCHAR_ARRAYS.length dimensional space with a coordinate on the county axis within self.counties, a coordinate on the zip_codes axis within self.zip_codes, etc.;
    # therefore 
    #           (1) an IGC with more nil varchar arrays is always bigger than one with less (since the nil stands for an array containing every possible value); hence the next entry in the returned array is the # of non-nil varchar arrays (the more nils ya got, the smaller the number ya got)
    #           (2) the number of points represented, i.e. the size of the set, is the product of the sizes of all of self's non-nil varchar arrays; to order from supersets to subsets we thus return the negative of this # as the last entry;
    # NOTE: blank varchar arrays are converted into nil ones in a before_validation callback. but just in case that hasn't run, the logic below uses .blank? instead of .nil?
    [self.state || '', VARCHAR_ARRAYS.count{|prop| !self.send(prop).blank? }, -VARCHAR_ARRAYS.inject(1){|prod, prop| self.send(prop).blank? ? prod : prod * self.send(prop).count }]
  end
  
  
  # Sorts them from most general to most specific;
  # sorting an array of IGCs will ensure that if one contains another,
  # the other is later in the list; addresses will always be manually entered last in the list
  def <=>(other)
    self.norm <=> other.norm
  end
  

  private

    def set_counties_nil_if_empty
      self.counties = nil if self.counties.blank?
    end

    def normalize_data
      VARCHAR_ARRAYS.each do |prop|
        if self.send(prop).blank?
          self.send("#{prop}=", nil)
        else
          self.send(prop).map!{|v| self.class.send("normalize_#{prop}_entry", v) }
          self.send(prop).sort!
          self.send(prop).uniq!
        end
      end
    end

    def nonempty_substate_data_implies_nonempty_state
      if state.nil?
        errors.add(:state, I18n.t('insurable_geographical_category.cannot_be_blank_if_data_are_specified')) if VARCHAR_ARRAYS.any?{|prop| !self.send(prop).blank? }
      end
    end

end
