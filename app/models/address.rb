# Address model
# file: +app/models/address.rb+

class Address < ApplicationRecord

  US_STATE_CODES = { AK: 0, AL: 1, AR: 2, AZ: 3, CA: 4, CO: 5, CT: 6,
                DC: 7, DE: 8, FL: 9, GA: 10, HI: 11, IA: 12, ID: 13,
                IL: 14, IN: 15, KS: 16, KY: 17, LA: 18, MA: 19, MD: 20,
                ME: 21, MI: 22, MN: 23, MO: 24, MS: 25, MT: 26, NC: 27,
                ND: 28, NE: 29, NH: 30, NJ: 31, NM: 32, NV: 33, NY: 34,
                OH: 35, OK: 36, OR: 37, PA: 38, RI: 39, SC: 40, SD: 41,
                TN: 42, TX: 43, UT: 44, VA: 45, VT: 46, WA: 47, WI: 48,
                WV: 49, WY: 50 }

  # A useful list to have around for broader state validations (scan app for uses before removing!)
  EXTENDED_US_STATE_CODES = { AK: 0, AL: 1, AR: 2, AZ: 3, CA: 4, CO: 5, CT: 6,
                DC: 7, DE: 8, FL: 9, GA: 10, HI: 11, IA: 12, ID: 13,
                IL: 14, IN: 15, KS: 16, KY: 17, LA: 18, MA: 19, MD: 20,
                ME: 21, MI: 22, MN: 23, MO: 24, MS: 25, MT: 26, NC: 27,
                ND: 28, NE: 29, NH: 30, NJ: 31, NM: 32, NV: 33, NY: 34,
                OH: 35, OK: 36, OR: 37, PA: 38, RI: 39, SC: 40, SD: 41,
                TN: 42, TX: 43, UT: 44, VA: 45, VT: 46, WA: 47, WI: 48,
                WV: 49, WY: 50,
                AS: 51, FM: 52, GU: 53, MH: 54, MP: 55, PW: 56, PR: 57,
                VI: 58, AE: 59, AP: 60, AA: 61 }

  # The great hell list of street abbreviations
  STREET_ABBREVIATIONS = {"ALLEY"=>"ALY", "ALLEE"=>"ALY", "ALLY"=>"ALY", "ANEX"=>"ANX", "ANNEX"=>"ANX", "ANNX"=>"ANX",
                          "ARCADE"=>"ARC", "AVENUE"=>"AVE", "AV"=>"AVE", "AVEN"=>"AVE", "AVENU"=>"AVE", "AVN"=>"AVE",
                          "AVNUE"=>"AVE", "BAYOU"=>"BYU", "BAYOO"=>"BYU", "BEACH"=>"BCH", "BEND"=>"BND", "BLUFF"=>"BLF",
                          "BLUF"=>"BLF", "BLUFFS"=>"BLFS", "BOTTOM"=>"BTM", "BOT"=>"BTM", "BOTTM"=>"BTM",
                          "BOULEVARD"=>"BLVD", "BOUL"=>"BLVD", "BOULV"=>"BLVD", "BRANCH"=>"BR", "BRNCH"=>"BR",
                          "BRIDGE"=>"BRG", "BRDGE"=>"BRG", "BROOK"=>"BRK", "BROOKS"=>"BRKS", "BURG"=>"BG",
                          "BURGS"=>"BGS", "BYPASS"=>"BYP", "BYPA"=>"BYP", "BYPAS"=>"BYP", "BYPS"=>"BYP", "CAMP"=>"CP",
                          "CMP"=>"CP", "CANYON"=>"CYN", "CANYN"=>"CYN", "CNYN"=>"CYN", "CAPE"=>"CPE", "CAUSEWAY"=>"CSWY",
                          "CAUSWA"=>"CSWY", "CENTER"=>"CTR", "CEN"=>"CTR", "CENT"=>"CTR", "CENTR"=>"CTR", "CENTRE"=>"CTR",
                          "CNTER"=>"CTR", "CNTR"=>"CTR", "CENTERS"=>"CTRS", "CIRCLE"=>"CIR", "CIRC"=>"CIR", "CIRCL"=>"CIR",
                          "CRCL"=>"CIR", "CRCLE"=>"CIR", "CIRCLES"=>"CIRS", "CLIFF"=>"CLF", "CLIFFS"=>"CLFS", "CLUB"=>"CLB",
                          "COMMON"=>"CMN", "COMMONS"=>"CMNS", "CORNER"=>"COR", "CORNERS"=>"CORS", "COURSE"=>"CRSE", "COURT"=>"CT",
                          "COURTS"=>"CTS", "COVE"=>"CV", "COVES"=>"CVS", "CREEK"=>"CRK", "CRESCENT"=>"CRES", "CRSENT"=>"CRES",
                          "CRSNT"=>"CRES", "CREST"=>"CRST", "CROSSING"=>"XING", "CRSSNG"=>"XING", "CROSSROAD"=>"XRD",
                          "CROSSROADS"=>"XRDS", "CURVE"=>"CURV", "DALE"=>"DL", "DAM"=>"DM", "DIVIDE"=>"DV", "DIV"=>"DV",
                          "DVD"=>"DV", "DRIVE"=>"DR", "DRIV"=>"DR", "DRV"=>"DR", "DRIVES"=>"DRS", "ESTATE"=>"EST",
                          "ESTATES"=>"ESTS", "EXPRESSWAY"=>"EXPY", "EXP"=>"EXPY", "EXPR"=>"EXPY", "EXPRESS"=>"EXPY",
                          "EXPW"=>"EXPY", "EXTENSION"=>"EXT", "EXTN"=>"EXT", "EXTNSN"=>"EXT", "EXTENSIONS"=>"EXTS",
                          "FALLS"=>"FLS", "FERRY"=>"FRY", "FRRY"=>"FRY", "FIELD"=>"FLD", "FIELDS"=>"FLDS", "FLAT"=>"FLT",
                          "FLATS"=>"FLTS", "FORD"=>"FRD", "FORDS"=>"FRDS", "FOREST"=>"FRST", "FORESTS"=>"FRST", "FORGE"=>"FRG",
                          "FORG"=>"FRG", "FORGES"=>"FRGS", "FORK"=>"FRK", "FORKS"=>"FRKS", "FORT"=>"FT", "FRT"=>"FT", "FREEWAY"=>"FWY",
                          "FREEWY"=>"FWY", "FRWAY"=>"FWY", "FRWY"=>"FWY", "GARDEN"=>"GDN", "GARDN"=>"GDN", "GRDEN"=>"GDN",
                          "GRDN"=>"GDN", "GARDENS"=>"GDNS", "GRDNS"=>"GDNS", "GATEWAY"=>"GTWY", "GATEWY"=>"GTWY", "GATWAY"=>"GTWY",
                          "GTWAY"=>"GTWY", "GLEN"=>"GLN", "GLENS"=>"GLNS", "GREEN"=>"GRN", "GREENS"=>"GRNS", "GROVE"=>"GRV",
                          "GROV"=>"GRV", "GROVES"=>"GRVS", "HARBOR"=>"HBR", "HARB"=>"HBR", "HARBR"=>"HBR", "HRBOR"=>"HBR",
                          "HARBORS"=>"HBRS", "HAVEN"=>"HVN", "HEIGHTS"=>"HTS", "HT"=>"HTS", "HIGHWAY"=>"HWY", "HIGHWY"=>"HWY",
                          "HIWAY"=>"HWY", "HIWY"=>"HWY", "HWAY"=>"HWY", "HILL"=>"HL", "HILLS"=>"HLS", "HOLLOW"=>"HOLW",
                          "HLLW"=>"HOLW", "HOLLOWS"=>"HOLW", "HOLWS"=>"HOLW", "INLET"=>"INLT", "ISLAND"=>"IS", "ISLND"=>"IS",
                          "ISLANDS"=>"ISS", "ISLNDS"=>"ISS", "ISLES"=>"ISLE", "JUNCTION"=>"JCT", "JCTION"=>"JCT", "JCTN"=>"JCT",
                          "JUNCTN"=>"JCT", "JUNCTON"=>"JCT", "JUNCTIONS"=>"JCTS", "JCTNS"=>"JCTS", "KEY"=>"KY", "KEYS"=>"KYS",
                          "KNOLL"=>"KNL", "KNOL"=>"KNL", "KNOLLS"=>"KNLS", "LAKE"=>"LK", "LAKES"=>"LKS", "LAND"=>"LAND",
                          "LANDING"=>"LNDG", "LNDNG"=>"LNDG", "LANE"=>"LN", "LIGHT"=>"LGT", "LIGHTS"=>"LGTS", "LOAF"=>"LF",
                          "LOCK"=>"LCK", "LOCKS"=>"LCKS", "LODGE"=>"LDG", "LDGE"=>"LDG", "LODG"=>"LDG", "LOOPS"=>"LOOP",
                          "MALL"=>"MALL", "MANOR"=>"MNR", "MANORS"=>"MNRS", "MEADOW"=>"MDW", "MEADOWS"=>"MDWS", "MDW"=>"MDW",
                          "MEDOWS"=>"MDWS", "MEWS"=>"MEWS", "MILL"=>"ML", "MILLS"=>"MLS", "MISSION"=>"MSN", "MISSN"=>"MSN",
                          "MSSN"=>"MSN", "MOTORWAY"=>"MTWY", "MOUNT"=>"MT", "MNT"=>"MT", "MOUNTAIN"=>"MTN", "MNTAIN"=>"MTN",
                          "MNTN"=>"MTN", "MOUNTIN"=>"MTN", "MTIN"=>"MTN", "MOUNTAINS"=>"MTNS", "MNTNS"=>"MTNS", "NECK"=>"NCK",
                          "ORCHARD"=>"ORCH", "ORCHRD"=>"ORCH", "OVL"=>"OVAL", "OVERPASS"=>"OPAS", "PARKS"=>"PARK", "PARKWAY"=>"PKWY",
                          "PARKWY"=>"PKWY", "PKWAY"=>"PKWY", "PKY"=>"PKWY", "PARKWAYS"=>"PKWY", "PKWYS"=>"PKWY", "PASS"=>"PASS",
                          "PASSAGE"=>"PSGE", "PATHS"=>"PATH", "PIKES"=>"PIKE", "PINE"=>"PNE", "PINES"=>"PNES", "PLACE"=>"PL",
                          "PLAIN"=>"PLN", "PLAINS"=>"PLNS", "PLAZA"=>"PLZ", "PLZA"=>"PLZ", "POINT"=>"PT", "POINTS"=>"PTS",
                          "PORT"=>"PRT", "PORTS"=>"PRTS", "PRAIRIE"=>"PR", "PRR"=>"PR", "RADIAL"=>"RADL", "RAD"=>"RADL",
                          "RADIEL"=>"RADL", "RAMP"=>"RAMP", "RANCH"=>"RNCH", "RANCHES"=>"RNCH", "RNCHS"=>"RNCH", "RAPID"=>"RPD",
                          "RAPIDS"=>"RPDS", "REST"=>"RST", "RIDGE"=>"RDG", "RDGE"=>"RDG", "RIDGES"=>"RDGS", "RIVER"=>"RIV",
                          "RVR"=>"RIV", "RIVR"=>"RIV", "ROAD"=>"RD", "ROADS"=>"RDS", "ROUTE"=>"RTE", "ROW"=>"ROW", "RUE"=>"RUE",
                          "RUN"=>"RUN", "SHOAL"=>"SHL", "SHOALS"=>"SHLS", "SHORE"=>"SHR", "SHOAR"=>"SHR", "SHORES"=>"SHRS",
                          "SHOARS"=>"SHRS", "SKYWAY"=>"SKWY", "SPRING"=>"SPG", "SPNG"=>"SPG", "SPRNG"=>"SPG", "SPRINGS"=>"SPGS",
                          "SPNGS"=>"SPGS", "SPRNGS"=>"SPGS", "SPURS"=>"SPUR", "SQUARE"=>"SQ", "SQR"=>"SQ", "SQRE"=>"SQ", "SQU"=>"SQ",
                          "SQUARES"=>"SQS", "SQRS"=>"SQS", "STATION"=>"STA", "STATN"=>"STA", "STN"=>"STA", "STRAVENUE"=>"STRA",
                          "STRAV"=>"STRA", "STRAVEN"=>"STRA", "STRAVN"=>"STRA", "STRVN"=>"STRA", "STRVNUE"=>"STRA", "STREAM"=>"STRM",
                          "STREME"=>"STRM", "STREET"=>"ST", "STRT"=>"ST", "STR"=>"ST", "STREETS"=>"STS", "SUMMIT"=>"SMT",
                          "SUMIT"=>"SMT", "SUMITT"=>"SMT", "TERRACE"=>"TER", "TERR"=>"TER", "THROUGHWAY"=>"TRWY", "TRACE"=>"TRCE",
                          "TRACES"=>"TRCE", "TRACK"=>"TRAK", "TRACKS"=>"TRAK", "TRK"=>"TRAK", "TRKS"=>"TRAK", "TRAFFICWAY"=>"TRFY",
                          "TRAIL"=>"TRL", "TRAILS"=>"TRL", "TRLS"=>"TRL", "TRAILER"=>"TRLR", "TRLRS"=>"TRLR", "TUNNEL"=>"TUNL",
                          "TUNEL"=>"TUNL", "TUNLS"=>"TUNL", "TUNNELS"=>"TUNL", "TUNNL"=>"TUNL", "TURNPIKE"=>"TPKE", "TRNPK"=>"TPKE",
                          "TURNPK"=>"TPKE", "UNDERPASS"=>"UPAS", "UNION"=>"UN", "UNIONS"=>"UNS", "VALLEY"=>"VLY", "VALLY"=>"VLY",
                          "VLLY"=>"VLY", "VALLEYS"=>"VLYS", "VIADUCT"=>"VIA", "VDCT"=>"VIA", "VIADCT"=>"VIA", "VIEW"=>"VW",
                          "VIEWS"=>"VWS", "VILLAGE"=>"VLG", "VILL"=>"VLG", "VILLAG"=>"VLG", "VILLG"=>"VLG", "VILLIAGE"=>"VLG",
                          "VILLAGES"=>"VLGS", "VILLE"=>"VL", "VISTA"=>"VIS", "VIST"=>"VIS", "VST"=>"VIS", "VSTA"=>"VIS",
                          "WALKS"=>"WALK", "WALL"=>"WALL", "WY"=>"WAY", "WAYS"=>"WAYS", "WELL"=>"WL", "WELLS"=>"WLS", "ALY"=>"ALY",
                          "ANX"=>"ANX", "ARC"=>"ARC", "AVE"=>"AVE", "BYU"=>"BYU", "BCH"=>"BCH", "BND"=>"BND", "BLF"=>"BLF",
                          "BLFS"=>"BLFS", "BTM"=>"BTM", "BLVD"=>"BLVD", "BR"=>"BR", "BRG"=>"BRG", "BRK"=>"BRK", "BRKS"=>"BRKS",
                          "BG"=>"BG", "BGS"=>"BGS", "BYP"=>"BYP", "CP"=>"CP", "CYN"=>"CYN", "CPE"=>"CPE", "CSWY"=>"CSWY",
                          "CTR"=>"CTR", "CTRS"=>"CTRS", "CIR"=>"CIR", "CIRS"=>"CIRS", "CLF"=>"CLF", "CLFS"=>"CLFS", "CLB"=>"CLB",
                          "CMN"=>"CMN", "CMNS"=>"CMNS", "COR"=>"COR", "CORS"=>"CORS", "CRSE"=>"CRSE", "CT"=>"CT",
                          "CTS"=>"CTS", "CV"=>"CV", "CVS"=>"CVS", "CRK"=>"CRK", "CRES"=>"CRES", "CRST"=>"CRST", "XING"=>"XING",
                          "XRD"=>"XRD", "XRDS"=>"XRDS", "CURV"=>"CURV", "DL"=>"DL", "DM"=>"DM", "DV"=>"DV", "DR"=>"DR",
                          "DRS"=>"DRS", "EST"=>"EST", "ESTS"=>"ESTS", "EXPY"=>"EXPY", "EXT"=>"EXT", "EXTS"=>"EXTS", "FLS"=>"FLS",
                          "FRY"=>"FRY", "FLD"=>"FLD", "FLDS"=>"FLDS", "FLT"=>"FLT", "FLTS"=>"FLTS", "FRD"=>"FRD", "FRDS"=>"FRDS",
                          "FRST"=>"FRST", "FRG"=>"FRG", "FRGS"=>"FRGS", "FRK"=>"FRK", "FRKS"=>"FRKS", "FT"=>"FT", "FWY"=>"FWY",
                          "GDN"=>"GDN", "GDNS"=>"GDNS", "GTWY"=>"GTWY", "GLN"=>"GLN", "GLNS"=>"GLNS", "GRN"=>"GRN", "GRNS"=>"GRNS",
                          "GRV"=>"GRV", "GRVS"=>"GRVS", "HBR"=>"HBR", "HBRS"=>"HBRS", "HVN"=>"HVN", "HTS"=>"HTS", "HWY"=>"HWY",
                          "HL"=>"HL", "HLS"=>"HLS", "HOLW"=>"HOLW", "INLT"=>"INLT", "IS"=>"IS", "ISS"=>"ISS", "ISLE"=>"ISLE",
                          "JCT"=>"JCT", "JCTS"=>"JCTS", "KY"=>"KY", "KYS"=>"KYS", "KNL"=>"KNL", "KNLS"=>"KNLS", "LK"=>"LK",
                          "LKS"=>"LKS", "LNDG"=>"LNDG", "LN"=>"LN", "LGT"=>"LGT", "LGTS"=>"LGTS", "LF"=>"LF", "LCK"=>"LCK",
                          "LCKS"=>"LCKS", "LDG"=>"LDG", "LOOP"=>"LOOP", "MNR"=>"MNR", "MNRS"=>"MNRS", "MDWS"=>"MDWS", "ML"=>"ML",
                          "MLS"=>"MLS", "MSN"=>"MSN", "MTWY"=>"MTWY", "MT"=>"MT", "MTN"=>"MTN", "MTNS"=>"MTNS", "NCK"=>"NCK",
                          "ORCH"=>"ORCH", "OVAL"=>"OVAL", "OPAS"=>"OPAS", "PARK"=>"PARK", "PKWY"=>"PKWY", "PSGE"=>"PSGE",
                          "PATH"=>"PATH", "PIKE"=>"PIKE", "PNE"=>"PNE", "PNES"=>"PNES", "PL"=>"PL", "PLN"=>"PLN", "PLNS"=>"PLNS",
                          "PLZ"=>"PLZ", "PT"=>"PT", "PTS"=>"PTS", "PRT"=>"PRT", "PRTS"=>"PRTS", "PR"=>"PR", "RADL"=>"RADL",
                          "RNCH"=>"RNCH", "RPD"=>"RPD", "RPDS"=>"RPDS", "RST"=>"RST", "RDG"=>"RDG", "RDGS"=>"RDGS", "RIV"=>"RIV",
                          "RD"=>"RD", "RDS"=>"RDS", "RTE"=>"RTE", "SHL"=>"SHL", "SHLS"=>"SHLS", "SHR"=>"SHR", "SHRS"=>"SHRS",
                          "SKWY"=>"SKWY", "SPG"=>"SPG", "SPGS"=>"SPGS", "SPUR"=>"SPUR", "SQ"=>"SQ", "SQS"=>"SQS", "STA"=>"STA",
                          "STRA"=>"STRA", "STRM"=>"STRM", "ST"=>"ST", "STS"=>"STS", "SMT"=>"SMT", "TER"=>"TER", "TRWY"=>"TRWY",
                          "TRCE"=>"TRCE", "TRAK"=>"TRAK", "TRFY"=>"TRFY", "TRL"=>"TRL", "TRLR"=>"TRLR", "TUNL"=>"TUNL", "TPKE"=>"TPKE",
                          "UPAS"=>"UPAS", "UN"=>"UN", "UNS"=>"UNS", "VLY"=>"VLY", "VLYS"=>"VLYS", "VIA"=>"VIA", "VW"=>"VW", "VWS"=>"VWS",
                          "VLG"=>"VLG", "VLGS"=>"VLGS", "VL"=>"VL", "VIS"=>"VIS", "WALK"=>"WALK", "WAY"=>"WAY", "WL"=>"WL", "WLS"=>"WLS"}

  geocoded_by :full

  before_save :set_full,
              :set_full_searchable,
              :from_full

	before_create :set_first_as_primary
  
  before_create :standardize

  after_validation :geocode
  
  # qbe concern calls this manually when needed. to avoid spamming the FCC it's currently off here, but can be turned on if really needed.
  #after_validation :get_county_from_fcc

  after_save :refresh_insurable_policy_type_ids,
    if: Proc.new{|addr| addr.addressable_type == "Insurable" }

  belongs_to :addressable,
    polymorphic: true,
    required: false

  enum state: US_STATE_CODES

  # scope :residential_communities, -> { joins(:insurable).where() }
  validates :state,
            inclusion: { in: US_STATE_CODES.keys.map(&:to_s), message: "%{value} #{I18n.t('address_model.is_not_a_valid_state')}" },
            unless: -> { [Lead].include?(addressable.class) || country != 'USA' || (country == 'USA' && state.present?) }

  def as_indexed_json(options={})
    as_json(options).merge location: { lat: latitude, lon: longitude }
  end

  def self.from_string(dat_strang, validate_properties: true)
    address = Address.new(full: dat_strang)
    parsed_address = StreetAddress::US.parse(dat_strang)
    if parsed_address.nil?
      address.errors.add(:address_string, I18n.t('address_model.is_not_a_valid_state'))
      return address
    end
    address.from_full
    address.set_full
    ['street_number', 'street_name', 'city', 'state', 'zip_code'].each do |prop|
      if address.send(prop).blank?
        address.errors.add(prop.to_sym, "is invalid")
      end
    end
    return address
  end

  # Address.full_street_address
  # Returns full street address of Address from available variables
  def full_street_address(disable_plus4: false)
    [combined_street_address(), street_two,
     combined_locality_region(), disable_plus4 ? zip_code : combined_zip_code()].compact
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
              self.state = parsed_address.state
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
                                    .gsub(/[^0-9a-z ]/i, '')
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

  def self.separate_street_number(address_line_one)
    splat = address_line_one.strip.split(" ").map{|x| x.strip }
    return false if splat.length == 1
    [splat[0], splat.drop(1).join(" ")]
  end

  def get_msi_addr(include_line2 = true)
    {
      Addr1: self.combined_street_address,
      City: self.city,
      StateProvCd: self.state,
      PostalCode: self.zip_code
    }.merge(include_line2 ? { Addr2: street_two.blank? ? nil : street_two } : {})
  end

  def get_confie_addr(include_line2 = true, address_type: "MailingAddress")
    {
      AddrTypeCd: address_type,
      Addr1: self.combined_street_address,
      City: self.city,
      StateProvCd: self.state,
      PostalCode: self.zip_code#,
      #County: self.county.blank? ? nil : self.county # MOOSE WARNING: do we really need this?
    }.compact.merge(!include_line2 ? {} :
      include_line2 == true ? (street_two.blank? ? {} : { Addr2: street_two }) :
      { Addr2: include_line2 }
    )
  end

  def refresh_insurable_policy_type_ids
    # update policy type ids (in case a newly created or changed address alters which policy types an insurable supports)
    self.addressable&.refresh_policy_type_ids(and_save: true)
  end
  
  def get_county_from_fcc
    if self.latitude && self.longitude && self.county.blank?
      # WARNING: we don't save an event for this because it's so trivial and because the address is generally not yet saved at this point
      fccs = FccService.new
      fccs.build_request(:area, lat: self.latitude, lon: self.longitude)
      result = (fccs.call[:data]["results"].map{|r| r["county_name"] }.uniq rescue [])
      if result.length == 1
        self.county = result.first
      end
    end
  end
  
  def parent_insurable_geographical_categories
    temp_igc = ::InsurableGeographicalCategory.new(
      state: self.state,
      counties: [self.county].compact,
      zip_codes: [self.zip_code].compact,
      cities: [self.city].compact
    )
    temp_igc.valid? # ensure before_validation callbacks run
    return temp_igc.query_for_parents(include_self: false)
  end

  def standardize
    fields = [:street_number, :street_name, :street_two, :city]
    dupper = self.dup
    dupper.street_two = nil
    dupper.set_full
    temp = ::Address.from_string(dupper.full)
    temp.street_two = self.street_two
    temp.set_full
    fields.each{|f| self.send("#{f.to_s}=", temp.send(f)) }
    self.set_full
  end

end
