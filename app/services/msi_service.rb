# Msi Service Model
# file: app/services/msi_service.rb
#

require 'base64'
require 'fileutils'

class MsiService

  def self.carrier_id
    5
  end
  
  def self.carrier
    @carrier ||= ::Carrier.find(5)
  end
  
  def self.displayable_error_for(msg, extended_msg = nil)
    return nil if msg.nil?
    if msg.start_with?("ADDR16") # address was invalid
      return I18n.t('msi_service.invalid_address')
    elsif msg.start_with?("ACS24 - ") # effective date was invalid (returns something like 'Effective Date 11/29/2020 is invalid.  Date must be between 12/2/2020 - 3/1/2021.')
      #tr = msg.split("ACS24 - ")&.[](1)
      #return tr.blank? ? nil : tr
      return I18n.t('msi_service.invalid_effective_date')
    end
    return nil
  end

  @@coverage_codes = {
    AllOtherPeril:                                { code: 1, limit: true },
    Theft:                                        { code: 2, limit: false },
    Hurricane:                                    { code: 3, limit: false },
    Wind:                                         { code: 4, limit: false },
    WindHail:                                     { code: 5, limit: false },
    EarthquakeDeductible:                         { code: 6, limit: true },
    CoverageA:                                    { code: 1001, limit: false },
    CoverageB:                                    { code: 1002, limit: false },
    CoverageC:                                    { code: 1003, limit: true },
    CoverageD:                                    { code: 1004, limit: true },
    CoverageE:                                    { code: 1005, limit: true },
    CoverageF:                                    { code: 1006, limit: true },
    PetDamage:                                    { code: 1007, limit: false },
    WaterBackup:                                  { code: 1008, limit: false },
    TenantsPlusPackage:                           { code: 1009, limit: false },
    ReplacementCost_UnscheduledPersonalProperty:  { code: 1010, limit: false },
    ScheduledPersonalProperty:                    { code: 1011, limit: false },
    ScheduledPersonalProperty_Jewelry:            { code: 1012, limit: true },
    ScheduledPersonalProperty_Furs:               { code: 1013, limit: true },
    ScheduledPersonalProperty_Silverware:         { code: 1014, limit: true },
    ScheduledPersonalProperty_FineArts:           { code: 1015, limit: true },
    ScheduledPersonalProperty_Cameras:            { code: 1016, limit: true },
    ScheduledPersonalProperty_MusicalEquipment:   { code: 1017, limit: true },
    ScheduledPersonalProperty_GolfEquipment:      { code: 1018, limit: true },
    ScheduledPersonalProperty_StampCollections:   { code: 1019, limit: true },
    ScheduledPersonalProperty_MensJewelry:        { code: 1020, limit: true },
    ScheduledPersonalProperty_WomensJewelry:      { code: 1021, limit: true },
    IncreasedPropertyLimits:                      { code: 1040, limit: true },
    IncreasedPropertyLimits_JewelryWatchesFurs:   { code: 1041, limit: false },
    IncreasedPropertyLimits_SilverwareGoldwarePewterware:
                                                  { code: 1042, limit: false },
    IncreasedPropertyLimits_JewelryWatches:       { code: 1043, limit: false },
    AnimalLiability:                              { code: 1060, limit: true },
    Earthquake:                                   { code: 1061, limit: false },
    WorkersCompensation:                          { code: 1062, limit: false },
    HomeDayCare:                                  { code: 1063, limit: false },
    InvoluntaryUnemployment:                      { code: 1064, limit: false },
    IdentityFraud:                                { code: 1065, limit: false },
    FireDepartmentService:                        { code: 1066, limit: false },
    SinkHole:                                     { code: 1067, limit: false },
    WindHailExclusion:                            { code: 1068, limit: false },
    OrdinanceOrLaw:                               { code: 1070, limit: false },
    LossAssessment:                               { code: 1071, limit: true },
    RefrigeratedProperty:                         { code: 1072, limit: false },
    RentalIncome:                                 { code: 1073, limit: false },
    FungiContents:                                { code: 1074, limit: false },
    ForcedEntryTheft:                             { code: 1076, limit: false },
    TenantsAdditionalProtection:                  { code: 1077, limit: false },
    FungiLiability:                               { code: 1078, limit: false },
    SelfStorageBuyBack:                           { code: 1081, limit: false }
  }
  
  INSTALLMENT_COUNT = { "Annual" => 0, "SemiAnnual" => 1, "Quarterly" => 3, "Monthly" => 10 }
  
  UNIVERSALLY_DISABLED_COVERAGE_OPTIONS = (1011..1021).to_a.map{|uid| uid.to_s }
  
  OVERRIDE_SPECIFICATION = {
    'CA' =>           {@@coverage_codes[:EarthquakeDeductible][:code].to_s => { 'category' => 'deductible', 'requirement' => 'forbidden' }},                # forbid earthquake ded unless earthquake cov selected
    'FL' =>           {
                        @@coverage_codes[:WindHailExclusion][:code].to_s => { 'category' => 'coverage', 'requirement' => 'forbidden' },                     # disable Wind/Hail Exclusion in FL
                        @@coverage_codes[:Hurricane][:code].to_s =>         { 'category' => 'deductible', 'requirement' => 'required' }                     # mandate Hurricane coverage
                      },
    'GA' =>           {@@coverage_codes[:WindHail][:code].to_s => { 'category' => 'deductible', 'requirement' => 'forbidden' }},                            # disable WindHail
    'GA_COUNTIES' =>  {@@coverage_codes[:WindHail][:code].to_s => { 'category' => 'deductible', 'requirement' => 'required' }},                             # enable WindHail & make sure it's required for counties ['Bryan', 'Camden', 'Chatham', 'Glynn', 'Liberty', 'McIntosh']
    'MD' =>           {@@coverage_codes[:HomeDayCare][:code].to_s => { 'category' => 'coverage', 'requirement' => 'forbidden' }},                           # disable HomeDayCare in MD
  }.deep_merge(['AK', 'CO', 'HI', 'KY', 'ME', 'MT', 'NC', 'NJ', 'UT', 'VT', 'WA'].map do |state|
    # disable theft deductibles for selected states
    [
      state,
      {@@coverage_codes[:Theft][:code].to_s => { 'category' => 'deductible', 'requirement' => 'forbidden' }}
    ]
  end.to_h){|k,a,b| a + b }
  
  TITLE_OVERRIDES = {
    @@coverage_codes[:ForcedEntryTheft][:code].to_s => Proc.new{|region| region == 'NY' ? "Burglary Limitation Coverage" : nil },
    @@coverage_codes[:WindHail][:code].to_s => Proc.new{|region| "Wind / Hail" }
  }
  
  DESCRIPTIONS = {
    '1003' => 'Personal property coverage protects your personal belongings and property.',
    '1004' => 'Coverage reimburses you for the cost of maintaining a comparable standard of living following a covered loss that exceeds your normal expenses prior to the loss, up to the policy limits.',
    '1005' => 'Liability coverage protects you in an event of negligent damage to your apartment, the community, or other residents.',
    '1006' => 'Coverage designed to pay for medical expenses to others who are accidentally injured on an insured location or by the activities of an insured, resident employee, or an animal owned by or in the care of an insured, up to the policy limits.',
    '1008' => 'This option covers your personal property in the event there is water/sewer back-up in your covered dwelling that begins off premises.',
    '1010' => 'This option provides coverage on a replacement cost basis instead of actual cash value.',
    '1076' => 'This option provides a discount by changing theft coverage to require physical evidence of forced entry and may require a police report.',
    '1' => 'The amount the insurer will deduct from a loss resulting from other peril not already listed (such as theft, hurricane or wind) before paying up to its policy limits.',
    '1007' => 'This option covers up to $500 for accidental damage caused by a pet such as stained carpet or chewed baseboards.',
    '1060' => 'This option provides an increased amount of liability protection when an insured is held liable for damages by a pet.',
    '1065' => 'This option provides coverage up to $5,000 for expenses incurred by an insured as a direct result of identity fraud.',
    '1075' => 'This option provides coverage to treat, remediate and eliminate a bed bug infestation in the residence.',
    '2' => 'The amount the insurer will deduct from a loss resulting from theft before paying up to its policy limits.',
    '5' => 'The amount the insurer will deduct from a loss resulting from wind or hail before paying up to its policy limits.',
    '1072' => 'This option provides up to $500 coverage for loss of covered property stored in freezers or refrigerators caused by power service interruption or mechanical failure in a freezer or fridge.',
    '1081' => 'This option allows the insured to buy back additional limits for personal property that is stored.',
    '1082' => 'The policy may be endorsed to insure against loss by theft when all or part of the residence.',
    '1061' => 'This option covers your personal property (up to $5,000) in the event of an earthquake.',
    '6' => 'The amount the insurer will deduct from a loss resulting from an earthquake before paying up to its policy limits.',
    '3' => 'The amount the insurer will deduct from a loss resulting from a hurricane before paying up to its policy limits.',
    '1077' => 'Increases Loss of Use to 40% and increases Rental Income Coverage to $10,000, from $3,000.',
    '1062' => 'Provides coverage for 1 full time outservant employee for a premium of $60.00.'
  }
  
  def self.renew_descriptions
    ::InsurableRateConfiguration.where(carrier_policy_type: CarrierPolicyType.where(policy_type_id: PolicyType::RESIDENTIAL_ID, carrier_id: self.carrier_id).take, configurer_type: "Carrier", configurer_id: self.carrier_id).each do |irc|
      next if irc.configuration['coverage_options'].blank?
      irc.configuration['coverage_options'].each do |uid, co|
        unless !co['description'].blank? || co['uid'].blank? || MsiService::DESCRIPTIONS[uid].blank?
          irc.configuration['coverage_options'].each{|co| co['description'] = MsiService::DESCRIPTIONS[uid] }
          irc.save
        end
      end
    end
  end
  
  def self.covopt_sort(a,b)
    (a[0] == '1' ? 999999 : 0) <=> (b[0] == '1' ? 999999 : 0)
  end
  
  LOSS_OF_USE_VARIATIONS = {
    standard: {
      loss_of_use: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageC][:code].to_s, 'coverage_not_selected' => @@coverage_codes[:TenantsAdditionalProtection][:code].to_s },
        'rule' => {
          'greatest_of_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 200000 },
            'percent' => 20,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      },
      loss_of_use_with_additional_protection: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => [@@coverage_codes[:CoverageC][:code].to_s, @@coverage_codes[:TenantsAdditionalProtection][:code].to_s] },
        'rule' => {
          'greatest_of_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 200000 },
            'percent' => 40,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      }
    },
    fourk: {
      loss_of_use: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageC][:code].to_s, 'coverage_not_selected' => @@coverage_codes[:TenantsAdditionalProtection][:code].to_s },
        'rule' => {
          'greatest_of_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 200000 },
            'percent' => 20,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      },
      loss_of_use_with_additional_protection: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => [@@coverage_codes[:CoverageC][:code].to_s, @@coverage_codes[:TenantsAdditionalProtection][:code].to_s] },
        'rule' => {
          'greatest_of_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 400000 },
            'percent' => 40,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      }
    },
    threek: {
      loss_of_use: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageC][:code].to_s, 'coverage_not_selected' => @@coverage_codes[:TenantsAdditionalProtection][:code].to_s },
        'rule' => {
          'greatest_of_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 300000 },
            'percent' => 30,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      },
      loss_of_use_with_additional_protection: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => [@@coverage_codes[:CoverageC][:code].to_s, @@coverage_codes[:TenantsAdditionalProtection][:code].to_s] },
        'rule' => {
          'greatest_of_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 300000 },
            'percent' => 40,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      }
    },
    tenpercent: {
      loss_of_use: {
        'subject' => @@coverage_codes[:CoverageD][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageC][:code].to_s },
        'rule' => {
          'compares_percent' => {
            'comparator' => '=',
            'percent' => 10,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      }#,
      #loss_of_use_with_additional_protection: nil
    }
  }
  
  RULE_SPECIFICATION = {
    'USA' => {
      'cov_e_100k_max' => { # 'Liability limit must be at most $100k'
        'subject' => @@coverage_codes[:CoverageE][:code].to_s,
        'condition' => true,
        'rule' => {
          'compares_fixed' => {
            'comparator' => '<=',
            'object' => { 'data_type' => 'currency', 'value' => 10000000 }
          }
        }
      },
      'animal_liability_less_than_300k' => { # 'Animal Liability Buyback limit must be less than $300k'
        'subject' => @@coverage_codes[:AnimalLiability][:code].to_s,
        'condition' => true,
        'rule' => {
          'compares_fixed' => {
            'comparator' => '<',
            'object' => { 'data_type' => 'currency', 'value' => 30000000 }
          }
        }
      },
      'animal_liability_max' => { # 'Animal liability cannot exceed Coverage E'
        'subject' => @@coverage_codes[:AnimalLiability][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageE][:code].to_s },
        'rule' => {
          'compares_coverage' => {
            'comparator' => '<=',
            'object' => @@coverage_codes[:CoverageE][:code].to_s
          }
        }
      },
      'theft_deductible' => { # 'Theft deductible cannot be less than the all perils deductible'
        'subject' => @@coverage_codes[:Theft][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:AllOtherPeril][:code].to_s },
        'rule' => {
          'compares_coverage' => {
            'comparator' => '>=',
            'object' => @@coverage_codes[:AllOtherPeril][:code].to_s
          }
        }
      }
    }.merge(LOSS_OF_USE_VARIATIONS[:standard]),
    'CA' => {
      'earthquake_deductible' => { # 'Earthquake deductible must be nonzero when earthquake coverage is selected'
        'subject' => @@coverage_codes[:EarthquakeDeductible][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:Earthquake][:code].to_s },
        'rule' => {
          'has_requirement' => 'required',
          'compares_fixed' => {
            'comparator' => '>',
            'object' => 0
          }
        }
      }
    },
    'CO' => LOSS_OF_USE_VARIATIONS[:fourk],
    'CT' => LOSS_OF_USE_VARIATIONS[:threek],
    'FL' => {
      'ordinance_or_law' => { # 'Ordinance Or Law limit must be 2.5% of Coverage C limit'
        'subject' => @@coverage_codes[:OrdinanceOrLaw][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageC][:code].to_s },
        'rule' => {
          'compares_percent' => {
            'comparator' => '=',
            'percent' => 2.5.to_d,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      },
      'five_hundred_only_hurricane_deductible' => { #'Hurricane deductible must be $500'
        'subject' => @@coverage_codes[:Hurricane][:code].to_s,
        'condition' => true,
        'rule' => {
          'compares_fixed' => {
            'comparator' => '=',
            'object' => { 'data_type' => 'currency', 'value' => 50000 }
          }
        }
      },
      'no_1000_all_peril' => { # 'All Perils must be less than $1000'
        'subject' => @@coverage_codes[:AllOtherPeril][:code].to_s,
        'condition' => true,
        'rule' => {
          'compares_fixed' => {
            'comparator' => '<',
            'object' => { 'data_type' => 'currency', 'value' => 100000 }
          }
        }
      }
    }.merge(LOSS_OF_USE_VARIATIONS[:tenpercent]),
    'KY' => LOSS_OF_USE_VARIATIONS[:fourk],
    'MD' => {
      'water_backup' => { # 'Water backup must be $5000 or equal to Coverage C limit'
        'subject' => @@coverage_codes[:WaterBackup][:code].to_s,
        'condition' => { 'coverage_selected' => @@coverage_codes[:CoverageC][:code].to_s },
        'rule' => {
          'equal_to_fixed_or_percent' => {
            'fixed' => { 'data_type' => 'currency', 'value' => 500000 },
            'percent' => 100,
            'object' => @@coverage_codes[:CoverageC][:code].to_s
          }
        }
      }
    },
    'ME' => LOSS_OF_USE_VARIATIONS[:fourk],
    'MT' => LOSS_OF_USE_VARIATIONS[:fourk],
    'UT' => LOSS_OF_USE_VARIATIONS[:fourk],
    'WA' => LOSS_OF_USE_VARIATIONS[:fourk],
  }.deep_merge(["AL", "CA", "DC", "MA", "NJ", "NV", "NY", "PA", "SC", "VA", "WI", "WY"].map do |st|
    [
      st,
      {
        'no_huge_all_peril' => { # 'There is no theft deductible large enough to let a $1000 all perils deductible be selected'
          'subject' => @@coverage_codes[:AllOtherPeril][:code].to_s,
          'condition' => true,
          'rule' => {
            'compares_fixed' => {
              'comparator' => '<',
              'object' => { 'data_type' => 'currency', 'value' => 100000 }
            }
          }
        }
      }
    ]
  end.to_h)
  
  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :compiled_rxml,
    :errors,
    :request,
    :action,
    :rxml,
    :coverage_codes

  #validates :action, 
  #  presence: true,
  #  format: {
  #    with: /GetOrCreateCommunity/QuotePolicy/BindPolicy/GetPolicyDetails/
  #  
  #    with: /getZipCode|PropertyInfo|getRates|getMinPrem|SendPolicyInfo|sendCancellationList|downloadAcordFile/, 
  #    message: 'must be from approved list' 
  #  }
  
  def initialize
    self.action = nil
    self.errors = nil
  end
  
  def event_params
    {
      verb: 'post',
      format: 'xml',
      interface: 'REST',
      endpoint: self.endpoint_for(self.action),
      process: "msi_#{self.action}"
    }
  end
  
  def build_request(action_name, **args)
    self.action = action_name
    self.errors = nil
    begin
      self.send("build_#{action_name}", **args)
    rescue ArgumentError => e
      self.errors = { arguments: e.message }
    end
    return self.errors.blank?
  end
  
  def endpoint_for(which_call)
    Rails.application.credentials.msi[:uri][ENV['RAILS_ENV'].to_sym] + "/#{which_call.to_s.camelize}"
  end
  

  def call
    # try to call
    call_data = {
      error: false,
      code: 200,
      message: nil,
      response: nil,
      data: nil
    }
    begin
      
      call_data[:response] = HTTParty.post(endpoint_for(self.action),
        body: compiled_rxml,
        headers: {
          'Content-Type' => 'text/xml'
        },
        ssl_version: :TLSv1_2
      )
          
    rescue StandardError => e
      call_data = {
        error: true,
        code: 500,
        message: 'Request Timeout',
        response: e
      }
      puts "\nERROR\n"
      ActionMailer::Base.mail(from: 'info@getcoveredinsurance.com', to: 'dev@getcoveredllc.com', subject: "MSI #{ action } error", body: call_data.to_json).deliver
    end
    # handle response
    if call_data[:error]
      puts 'ERROR ERROR ERROR'.red
      pp call_data
    else
      call_data[:data] = call_data[:response].parsed_response # WARNING: if staging server doesn't parse to json, we might need this and its fellows: xml_doc = Nokogiri::XML(call_data[:data])
      case call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "MsgStatusCd")
        when 'SUCCESS'
          # it worked! huzzah!
        when 'ERROR'
          call_data[:error] = true
          call_data[:message] = "Request failed externally"
          call_data[:external_message] = call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "MsgStatusDesc").to_s
          call_data[:extended_external_message] = [call_data[:data].dig("MSIACORD", "InsuranceSvcRs", "MsgStatus", "ExtendedStatus")].flatten.compact
            .map{|el| "#{el["ExtendedStatusCd"]}: #{el["ExtendedStatusDesc"]}" }.join("\n")
          call_data[:code] = 409
        when nil
          call_data[:error] = true
          call_data[:message] = "Request failed externally"
          call_data[:external_message] = "No status message received"
          call_data[:code] = 409
      end
      
    end
    # scream to the console for the benefit of any watchers
    display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
    display_status_color = call_data[:error] ? :red : :green
    puts "#{'['.yellow} #{'MSI Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
    # all done
    return call_data
  end
  
  

  
  
  
  
  
  
  
  # address part params values:
  #   true:         required in address
  #   false:        omitted even if in address
  #   nil:          use if present in address, otherwise leave out
  #   :nil (sym):   set to nil but do not purge
  #   some string:  use the string provided (overriding whatever is provided in address, if necessary)
  def untangle_address_params(address: nil, address_line_one: true, address_line_two: nil, city: true, state: true, zip: true, throw_errors: true)
    case address
      when ::Address
        address = address.get_msi_addr(address_line_two != false)
      when ::Hash
        # do nothing
      when ::NilClass
        address = {}
      else
        raise ArgumentError.new("address parameter provided with invalid class '#{address.class.name}'") if throw_errors
        address = {}
    end
    lexicon = { Addr1: 'address_line_one', Addr2: 'address_line_two', City: 'city', StateProvCd: 'state', PostalCode: 'zip' }
    valid_keys = lexicon.transform_values{|v| eval(v) }.select{|k,v| v != false }
    address.transform_keys!{|k| k.to_sym }.delete_if{|k| !valid_keys.has_key?(k) }
    valid_keys.each do |k,v|
      address[k] = v unless v.nil? || v == true
    end
    address.compact!
    address.transform_values!{|v| v == :nil ? nil : v }
    if throw_errors
      missing_params = valid_keys.select{|k,v| v == true }.keys - address.keys
      unless missing_params.blank?
        raise ArgumentError.new("missing keywords: #{missing_params.map{|mp| lexicon[mp] }.join(", ")}")
      end
    end
    return address
  end
  
  
  def build_get_product_definition(
    effective_date:, state:,
    **compilation_args
  )
    # it's go time
    self.action = :get_product_definition
    self.errors = nil
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: {
            '': { id: "0" },
            Addr: {
              StateProvCd:                state
            }
          },
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                effective_date.strftime("%F")
            }
          },
          HomeLineBusiness: {
            Dwell: {
              '': { LocationRef: "0", id: "Dwell1" },
              PolicyTypeCd: "H04"
            }
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  
  def build_get_or_create_community(
      effective_date: Time.current.to_date + 2.days,
      community_name:, number_of_units:, property_manager_name:, years_professionally_managed:, year_built:, gated:,
      address: nil, address_line_one: nil, city: nil, state: nil, zip: nil,
      **compilation_args
  )
    # do some fancy dynamic stuff with parameters
    address = untangle_address_params(**{ address: address, address_line_one: address_line_one, city: city, state: state, zip: zip }.compact)
    # put the request together
    self.action = :get_or_create_community
    self.errors = nil
    unless year_built.nil? # MSI system requires YB>=1900; they told us older buildings should be submitted as built in 1900
      year_built = year_built.to_i
      year_built = 1900 if year_built < 1900
    end
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          MSI_CommunityInfo: {
            MSI_CommunityName:                community_name,
            MSI_CommunityYearsProfManaged:    years_professionally_managed.nil? ? 6 : years_professionally_managed,
            MSI_PropertyManagerName:          property_manager_name,
            MSI_NumberOfUnits:                number_of_units,
            MSI_CommunitySalesRepID:          Rails.application.credentials.msi[:csr][ENV["RAILS_ENV"].to_sym].to_s,
            MSI_CommunityYearBuilt:           year_built,
            MSI_CommunityIsGated:             gated.nil? ? true : gated,
            Addr:                             address
          },
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                    effective_date.strftime("%F")
            }
          },
          HomeLineBusiness: {
            Dwell: {
              :'' => { LocationRef: 0, id: "Dwell1" },
              PolicyTypeCd: 'H04'
            }
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end

  def build_final_premium(
    effective_date:, additional_insured_count:, additional_interest_count:,
    coverages_formatted:,
    # for preferred
    community_id: nil, #address_line_one:, city:, state:, zip:,
    # for non-preferred
    number_of_units: nil, years_professionally_managed: nil, year_built: nil, gated: nil,
    address: nil, address_line_one: nil, address_line_two: nil, city: nil, state: nil, zip: nil,
    # comp args
    **compilation_args
  )
    # setup
    self.action = :final_premium
    self.errors = nil
    # arguing with arguments
    if additional_insured_count > 7
      return ['Additional insured count cannot exceed 7']
    elsif additional_interest_count > 2
      return ['Additional interest count cannot exceed 2']
    end
    # handling distinctive preferred/nonpreferred arguments
    preferred = !community_id.nil?
    self.action = :final_premium_spot unless preferred
    if preferred
      return ['Community id cannot be blank'] if community_id.nil? # this can't happen, but for completeness in case we later determine prefered by different means...
    else
      address = untangle_address_params(**{ address: address, address_line_one: address_line_one, address_line_two: address_line_two, city: city, state: state, zip: zip }.compact)
      # applying defaults (we don't do this in the args themselves because nil might be passed)
      number_of_units ||= 50
      years_professionally_managed ||= 6
      year_built ||= 2002
      year_built = 1900 if year_built && year_built.to_i < 1900
      gated = false unless gated == true
    end
    # go go go
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: {
            '': { id: '0' },
            Addr: preferred ? {
              MSI_CommunityID:                community_id
            } :                               address
          },
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                    effective_date.strftime("%m/%d/%Y")
            }
          },
          HomeLineBusiness: {
            Dwell: {
              :'' => { LocationRef: 0, id: "Dwell1" },
              PolicyTypeCd: 'H04'
            }.merge(preferred ? {} : {
              Construction: { YearBuilt:      year_built }
            }),
            Coverage:                         coverages_formatted
          },
          InsuredOrPrincipal: [
            InsuredOrPrincipalInfo: {
              InsuredOrPrincipalRoleCd: "PRIMARYNAMEDINSURED"
            }
          ] + (0...additional_insured_count).map{|n| { InsuredOrPrincipalInfo: { InsuredOrPrincipalRoleCd: "OTHERNAMEDINSURED" } } } +
              (0...additional_interest_count).map{|n| { InsuredOrPrincipalInfo: { InsuredOrPrincipalRoleCd: "ADDITIONALINTEREST" } } }
        }.merge(preferred ? {} : {
          MSI_CommunityInfo: {
            MSI_CommunityYearBuilt:           year_built,
            MSI_CommunityIsGated:             gated ? "True" : "False",
            MSI_CommunityYearsProfManaged:    years_professionally_managed,
            MSI_NumberOfUnits:                number_of_units
          }
        })
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_bind_policy(
    effective_date:,
    payment_plan:, installment_day:,
    unit: nil,
    unit_prefix: unit.nil? ? nil : "Apartment",
    address: nil, address_line_one: nil, city: nil, state: nil, zip: nil,
    maddress: nil, maddress_line_one: nil, maddress_line_two: nil, mcity: nil, mstate: nil, mzip: nil,
    payment_merchant_id:, payment_processor:, payment_method:, payment_info:, payment_other_id:,
    primary_insured:, additional_insured:, additional_interest:,
    coverage_raw:, # WARNING: raw msi formatted coverage hash; modify later to accept a nicer format
    # for preferred
    community_id: nil,
    # for non-preferred
    address_line_two: nil,
    number_of_units: nil, years_professionally_managed: nil, year_built: nil, gated: nil,
    # comp args 
    **compilation_args
  )
    # set up
    self.action = :bind_policy
    self.errors = nil
    # arguing with arguments
    if additional_insured.count > 7
      return ['Additional insured count cannot exceed 7']
    elsif additional_interest.count > 2
      return ['Additional interest count cannot exceed 2']
    end
    address = untangle_address_params(**{ address: address, address_line_one: address_line_one, address_line_two: unit.nil? ? (address_line_two || false) : "#{unit_prefix ? unit_prefix.strip + " " : ""}#{unit}", city: city, state: state, zip: zip }.compact)
    # handling distinctive preferred/nonpreferred arguments
    preferred = !community_id.nil?
    self.action = :bind_policy_spot unless preferred
    if preferred
      return ['Community id cannot be blank'] if community_id.nil? # this can't happen, but for completeness in case we later determine prefered by different means...
    else
      # applying defaults (we don't do this in the args themselves because nil might be passed)
      number_of_units ||= 50
      years_professionally_managed ||= 6
      year_built ||= 2002
      year_built = 1900 if year_built && year_built.to_i < 1900
      gated = false unless gated == true
    end
    # handling mailing address
    if !maddress.nil? || !maddress_line_one.nil? || !maddress_line_two.nil? || !mcity.nil? || !mstate.nil? || !mzip.nil?
      maddress = untangle_address_params(**{ address: maddress, address_line_one: maddress_line_one, address_line_two: maddress_line_two || nil, city: mcity, state: mstate, zip: mzip }.compact)
    else
      maddress = address
    end
    # go go go
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: [
            {
              '': { id: '0' },
              Addr:                           address.merge(preferred ? {
                MSI_CommunityID:                community_id,
                MSI_Unit:                       unit
             }.compact : {})
            }.compact
          ] + (maddress == address ? [] : [
            {
              '': { id: '1' },
              Addr:                           maddress
            }
          ]),
          PersPolicy: {
            ContractTerm: {
              EffectiveDt:                    effective_date.strftime("%m/%d/%Y")
            },
            PaymentPlan: {
              PaymentPlanCd:                  payment_plan,
              InstallmentDayofMonth:          installment_day
            },
            PaymentMethod: {
              MSI_PaymentMerchantID:          payment_merchant_id,
              MSI_PaymentProcessor:           payment_processor,
              MethodPaymentCd:                payment_method
            }.merge(                          payment_info)
          },
          HomeLineBusiness: {
            Dwell: {
              :'' => { LocationRef: 0, id: "Dwell1" },
              PolicyTypeCd: 'H04'
            }.merge(preferred ? {} : {
              Construction: { YearBuilt:      year_built }
            }),
            Coverage: coverage_raw
          },
          InsuredOrPrincipal: [
            {
              ItemIdInfo: {
                OtherIdentifier: {
                  OtherIdTypeCd: "CustProfileId",
                  OtherId:                    payment_other_id
                },
              },
              InsuredOrPrincipalInfo: {
                InsuredOrPrincipalRoleCd: "PRIMARYNAMEDINSURED"
              },
              GeneralPartyInfo:             primary_insured.class == ::User ? primary_insured.get_msi_general_party_info : primary_insured
            }
          ] + additional_insured.map do |ai|
            {
              InsuredOrPrincipalInfo: {
                InsuredOrPrincipalRoleCd: "OTHERNAMEDINSURED"
              },
              GeneralPartyInfo:               ai.class == ::User ? ai.get_msi_general_party_info : ai
            }
          end + additional_interest.map do |ai|
            {
              InsuredOrPrincipalInfo: {
                InsuredOrPrincipalRoleCd: "ADDITIONALINTEREST"
              },
              GeneralPartyInfo:               [::User, ::Account].include?(ai.class) ? ai.get_msi_general_party_info : ai
            }
          end
        }.merge(preferred ? {} : {
          MSI_CommunityInfo: {
            MSI_CommunityYearBuilt:           year_built,
            MSI_CommunityIsGated:             gated ? "True" : "False",
            MSI_CommunityYearsProfManaged:    years_professionally_managed,
            MSI_NumberOfUnits:                number_of_units
          }
        })
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_policy_details(
    policy_number:,
    **compilation_args
  )
    self.action = :policy_details
    self.errors = nil
    # w000t
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          MSI_PolicySearch: {
            PolicyNumber:                     policy_number
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_policy_download(
    start_datetime:, end_datetime:,
    ignore_start_time: false, ignore_end_time: false, ignore_times: false,
    **compilation_args
  )
    self.action = :policy_download
    self.errors = nil
    # param magic
    if ignore_times
      ignore_start_time = true
      ignore_end_time = true
    end
    start_time_code = (ignore_start_time ? "%F" : "%F %T")
    end_time_code = (ignore_end_time ? "%F" : "%F %T")
    # w00t!!!
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          TransactionStartDate:               start_datetime.strftime(start_time_code),
          TransactionEndDate:                 end_datetime.strftime(end_time_code)
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_claims_download(
    start_datetime:, end_datetime:,
    ignore_start_time: false, ignore_end_time: false, ignore_times: false,
    **compilation_args
  )
    self.action = :claims_download
    self.errors = nil
    # param magic
    if ignore_times
      ignore_start_time = true
      ignore_end_time = true
    end
    start_time_code = (ignore_start_time ? "%F 00:00:00" : "%F %T")
    end_time_code = (ignore_end_time ? "%F 23:59:59" : "%F %T")
    # yepperdoodles!!!
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          TransactionStartDate:               start_datetime.strftime(start_time_code),
          TransactionEndDate:                 end_datetime.strftime(end_time_code)
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  def build_get_credit_card_pre_authorization_token(
    state:, product_id:,
    **compilation_args
  )
    self.action = :get_credit_card_pre_authorization_token
    self.errors = nil
    # do it bro, I dare you
    self.compiled_rxml = compile_xml({
      InsuranceSvcRq: {
        RenterPolicyQuoteInqRq: {
          Location: {
            Addr: {
              StateProvCd:                    state
            }
          },
          PersPolicy: {
            CompanyProductCd:                 product_id
          }
        }
      }
    }, **compilation_args)
    return errors.blank?
  end
  
  
  
  def extract_insurable_rate_configuration(product_definition_response, configurer: nil, configurable: nil, carrier_policy_type: nil, use_default_rules_for: nil)
    irc = InsurableRateConfiguration.new(configurer: configurer, configurable: configurable, carrier_policy_type: carrier_policy_type)
    irc.configuration = { 'coverage_options' => {}, 'rules' => {} }
    unless product_definition_response.nil?
      # grab relevant bois from out da hood
      product = product_definition_response.dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "MSI_ProductDefinition")
      coverages = arrayify(product.dig("MSI_ProductCoverageList", "MSI_ProductCoverageDefinition"))
      deductibles = arrayify(product.dig("MSI_ProductDeductibleList", "MSI_ProductDeductibleDefinition"))
      payment_plans = product.dig("MSI_ProductPaymentPlanDefinition", "MSI_ProductPaymentPlanDefinition")
      # transcribe into IRC object
      irc.carrier_info = {
        "effective_date"      => product["MSI_EffectiveDate"],
        "underwriter_id"      => product["MSI_UnderwritingCompanyID"],
        "underwriter_name"    => product["MSI_UnderwritingCompanyName"],
        "product_id"          => product["MSI_ProductID"],
        "product_version_id"  => product["MSI_ProductVersionID"],
        "payment_plans"       => payment_plans.map do |plan|
          {
            plan["MSI_PaymentPlanType"] => {
              (plan["MSI_PolicyTermType"] == 'New' ? 'new_business' : plan["MSI_PolicyTermType"] == 'Renewal' ? 'renewal' : plan["MSI_PolicyTermType"]) => {
                "down_payment_percent" => (plan["MSI_DownPaymentPct"].to_d * 100.to_d),
                "installment_fee" => plan["MSI_InstallmentFeeAmt"].to_d
              }
            }
          }
        end.inject({}){|combined,single| combined.deep_merge(single) }
      }
      irc.configuration['coverage_options'] = (coverages.map do |cov|
          [cov["CoverageCd"].to_s, {
            "title"         => (TITLE_OVERRIDES[cov["CoverageCd"].to_s].class == ::Proc ?
              TITLE_OVERRIDES[cov["CoverageCd"].to_s].call(use_default_rules_for.to_s)
              : TITLE_OVERRIDES[cov["CoverageCd"].to_s]) || cov["CoverageDescription"].titleize,
            "requirement"   => (cov["MSI_IsMandatoryCoverage"] || "").strip == "True" ? 'required' : 'optional',
            "visible"       => true,
            "category"      => "coverage",
            "options_type"  => cov["MSI_LimitList"].blank? ? "none" : "multiple_choice",
            "options"       => cov["MSI_LimitList"].blank? ? nil : arrayify(cov["MSI_LimitList"]["string"]).map{|v| { 'data_type' => 'currency', 'value' => (v.to_d*100).to_i } }
          }.compact]
        end + deductibles.map do |ded|
          [ded["MSI_DeductibleCd"].to_s, {
            "title"         => (TITLE_OVERRIDES[ded["MSI_DeductibleCd"].to_s].class == ::Proc ?
              TITLE_OVERRIDES[ded["MSI_DeductibleCd"].to_s].call(use_default_rules_for.to_s)
              : TITLE_OVERRIDES[ded["MSI_DeductibleCd"].to_s]) || ded["MSI_DeductibleName"].titleize,
            "requirement"   => 'required', #MOOSE WARNING: in special cases some are optional, address these
            "visible"       => true,
            "category"      => "deductible",
            "options_type"  => ded["MSI_DeductibleOptionList"].blank? ? "none" : "multiple_choice",
            "options"       => ded["MSI_DeductibleOptionList"].blank? ? nil : arrayify(ded["MSI_DeductibleOptionList"]["Deductible"]).map{|d| d["Amt"] ? { 'data_type' => 'currency', 'value' => (d["Amt"].to_d*100).to_i } : { 'data_type' => 'percentage', 'value' => d["FormatPct"].to_d * 100 } }
          }.compact]
      end).sort{|a,b| MsiService.covopt_sort(a,b) }.to_h
    end
    # apply descriptions
    irc.configuration['coverage_options'].each{|uid, co| co['description'] = DESCRIPTIONS[uid] unless DESCRIPTIONS[uid].blank? }
    # apply universal disablings
    irc.configuration['coverage_options'].select{|uid, co| UNIVERSALLY_DISABLED_COVERAGE_OPTIONS.any?{|udco| udco == uid } }
                                         .each{|uid, co| co['requirement'] = 'forbidden' }
    # apply overrides, if any
    (OVERRIDE_SPECIFICATION[use_default_rules_for.to_s] || []).each do |uid, ovrd|
      irc.configuration['coverage_options'][uid] ||= {}
      irc.configuration['coverage_options'][uid].merge!(ovrd)
    end
    # set rules, if any
    irc.configuration['rules'] = RULE_SPECIFICATION[use_default_rules_for.to_s] || {}
    return irc
  end
  
  
  
  
  def self.validate_msi_additional_interest(hash)
    case hash['entity_type']
      when 'company'
        return 'msi_service.additional_interest.company_name_required' if hash['company_name'].blank?
        return 'msi_service.additional_interest.company_name_too_long' if hash['company_name'].length > 100
        return 'msi_service.additional_interest.invalid_email' if hash['email_address'].blank? || hash['email_address'].index('@').nil? || hash['email_address'].index('.').nil? || hash['email_address'].length > 50
        return 'msi_service.additional_interest.invalid_phone_number' if !hash['phone_number'].blank? && hash['phone_number'].delete("^0-9").length != 10
      when 'person'
        return 'msi_service.additional_interest.first_name_required' if hash['first_name'].blank?
        return 'msi_service.additional_interest.first_name_too_long' if hash['first_name'].length > 50
        return 'msi_service.additional_interest.last_name_required' if hash['last_name'].blank?
        return 'msi_service.additional_interest.last_name_too_long' if hash['last_name'].length > 50
        return 'msi_service.additional_interest.middle_name_too_long' if hash['middle_name'] && hash['middle_name'].length > 50
        return 'msi_service.additional_interest.invalid_email' if hash['email_address'].blank? || hash['email_address'].index('@').nil? || hash['email_address'].index('.').nil? || hash['email_address'].length > 50
        return 'msi_service.additional_interest.invalid_phone_number' if hash['phone_number'].blank? || hash['phone_number'].delete("^0-9").length != 10
        
      else
        return 'msi_service.additional_interest.invalid_entity_type'
    end
    return nil
  end
  
  
private

    def arrayify(val, nil_as_object: false)
      val.class == ::Array ? val : val.nil? && !nil_as_object ? [] : [val]
    end

    def get_auth_json
      {
        SignonRq: {
          SignonPswd: {
            CustId: {
              CustLoginId: Rails.application.credentials.msi[:un][ENV['RAILS_ENV'].to_sym]
            },
            CustPswd: {
              Pswd: Rails.application.credentials.msi[:pw][ENV['RAILS_ENV'].to_sym]
            }
          }
        }
      }
    end
    
    def json_to_xml(obj, abbreviate_nils: true, closeless: false,  indent: nil, line_breaks: false, internal: false)
      # dynamic default parameters
      line_breaks = true unless indent.nil?
      indent = "" if line_breaks && indent.nil?
      # go wild
      prop_string = ""
      child_string = ""
      case obj
        when ::Hash
          # handle properties to pass back up to our caller
          if obj.has_key?(:'')
            prop_string = obj[:''].blank? ? "" : obj[:''].class == ::String ? obj[:''] :
              obj[:''].map{|k,v| "#{k}=\"#{v.to_s.gsub('&', '&amp;').gsub('"', '&quot;').gsub('<', '&lt;')}\"" }.join(" ")
            prop_string = " #{prop_string}" unless prop_string.blank?
            obj = obj.select{|k,v| k != :'' }
          end
          # convert ourselves into an xml string
          child_string = obj.map do |k,v|
            # induce recursion and set line break settings
            subxml_result = json_to_xml(v, abbreviate_nils: abbreviate_nils, indent: indent.nil? ? nil : indent + "  ", internal: true)
            subxml_result = [subxml_result] unless subxml_result.class == ::Array
            subxml_result.map do |subxml|
              line_mode = subxml.nil? ? :cancel : !line_breaks ? :none : (subxml[:child_string].nil? || (subxml[:child_string].index("\n").nil? && subxml[:child_string].length < 64)) ? :inline : :block
              # return our fancy little text block
              case line_mode
                when :none, :inline
                  "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
                    : (">#{subxml[:child_string].to_s}" + (closeless ? "" : "</#{k}>")))
                when :block
                  "<#{k}#{subxml[:prop_string]}" + ((abbreviate_nils && subxml[:child_string].nil?) ? "/>"
                    : (">\n#{indent}  #{subxml[:child_string].to_s}" + (closeless ? "" : "\n#{indent}</#{k}>")))
                when :cancel
                  nil
              end
            end
          end.flatten.compact.join(line_breaks ? "\n#{indent}" : "")
        when ::Array
          return obj.map{|v| json_to_xml(v, abbreviate_nils: abbreviate_nils, indent: indent, internal: true) }
        when ::NilClass
          child_string = nil
        else
          child_string = obj.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").split("\n").join("#{indent}\n")
      end
      internal ? {
        prop_string: prop_string,
        child_string: child_string
      } : child_string
    end
  
    def compile_xml(obj, line_breaks: false, **other_args)
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>#{line_breaks ? "\n" : ""}" + json_to_xml({
        MSIACORD: {
          '': {
            'xmlns:xsd': 'http://www.w3.org/2001/XMLSchema',
            'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance'
          }
        }.merge(get_auth_json).merge(obj)
      },
        line_breaks: line_breaks,
        **other_args
      )
    end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
end


