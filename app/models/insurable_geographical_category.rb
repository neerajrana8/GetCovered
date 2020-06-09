class InsurableGeographicalCategory < ApplicationRecord
  extend ArrayEnum
  
  belongs_to :configurer, polymorphic: true   # Account, Agency, or Carrier
  belongs_to :carrier_insurable_type
  
  US_STATE_CODES = { AK: 0, AL: 1, AR: 2, AZ: 3, CA: 4, CO: 5, CT: 6, 
                DC: 7, DE: 8, FL: 9, GA: 10, HI: 11, IA: 12, ID: 13, 
                IL: 14, IN: 15, KS: 16, KY: 17, LA: 18, MA: 19, MD: 20, 
                ME: 21, MI: 22, MN: 23, MO: 24, MS: 25, MT: 26, NC: 27, 
                ND: 28, NE: 29, NH: 30, NJ: 31, NM: 32, NV: 33, NY: 34, 
                OH: 35, OK: 36, OR: 37, PA: 38, RI: 39, SC: 40, SD: 41, 
                TN: 42, TX: 43, UT: 44, VA: 45, VT: 46, WA: 47, WI: 48, 
                WV: 49, WY: 50 } # WARNING: this should always match the state codes in Address

  array_enum state: US_STATE_CODES
  
  def get_parents(mutable: nil)
    generic_superset_query(
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
  end

  
  private
  
    def generic_superset_query(starting_query = InsurableGeographicalCategory.all)
      starting_query
        .where('city IS NULL OR city @> ARRAY[?]::string[]', city)
        .where('state IS NULL OR state @> ARRAY[?]::integer[]', state.map{|s| self.class.states[s] }) # MOOSE WARNING: state?
        .where('zip_code IS NULL OR zip_code @> ARRAY[?]::string[]', zip_code)
        .where('county IS NULL OR county @> ARRAY[?]::string[]', county)
        .where(carrier_insurable_type_id: carrier_insurable_type_id)
    end
end
