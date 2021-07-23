
class InsurableRateConfiguration < ApplicationRecord

  include Structurable
  include Scriptable

  # ActiveRecord Associations
  
  belongs_to :configurable, polymorphic: true # Insurable or InsurableGeographicCategory (for now)
  belongs_to :configurer, polymorphic: true   # Account, Agency, or Carrier
  belongs_to :carrier_insurable_type
  
  # Convenience associations to particular types of configurable
  belongs_to :insurable_geographical_category,
    -> { where(insurable_rate_configurations: {configurable_type: 'InsurableGeographicalCategory'}) },
    foreign_key: 'configurable_id',
    optional: true
  def insurable_geographical_category
   return nil unless configurable_type == "InsurableGeographicalCategory"
   super
  end
  
  # Callbacks
  
  before_save :refresh_max_overridability,
    if: Proc.new{|irc| irc.will_save_change_to_attribute?('configuration') } # MOOSE WARNING: should we apply copy_with_serialization?
  
  # Validations
  
  validate :validate_configuration
  
  # Structurable structures used in this model

  CONFIGURATION_STRUCTURE = {
    'coverage_options' => {
      'required' => false,
      'validity' => Proc.new{|v| v.class == ::Hash },
      'default_overridability' => 0,
      'default_value' => {},
    
      'special' => 'hash',
      'special_data' => {
        'structure' => {
          'category' => {
            'required' => true,
            'validity' => ['coverage', 'deductible'],
            'default_overridability' => 0 
          },
          'external_id' => {
            'required' => true,
            'validity' => Proc.new{|v| v.class == ::String },
            'default_overridability' => 0
          },
          'title' => {
            'required' => true,
            'validity' => Proc.new{|v| v.class == ::String },
            'default_overridability' => 0
          },
          'description' => {
            'required' => false,
            'validity' => Proc.new{|v| v.nil? || v.class == ::String },
            'default_overridability' => Proc.new{|v,uid,data,irc| v.nil? ? nil : 0 }
          },
          'visible' => {
            'required' => true,
            'validity' => [true, false],
            'default_overridability' => 0
          },
          'requirement' => {
            'required' => true,
            'validity' => ['optional', 'required', 'forbidden'],
            'default_overridability' => Proc.new{|v| v == 'optional' ? nil : 0 }
          },
          'options_type' => {
            'required' => true,
            'validity' => ['multiple_choice', 'none'],
            'default_overridability' => 0
          },
          'options' => {
            'required' => Proc.new{|v,datum| datum['options_type'] == 'multiple_choice' },
            'validity' => Proc.new{|v| v.class == ::Array },
            'default_overridability' => 0,
            
            'special' => 'array',
            'special_data' => {
              'identity_keys' => ['data_type', 'value'],
              'remove_missing' => 'different_overridabilities', # could also be false or true
              'structure' => {
                'value' => {
                  'required' => true,
                  'validity' => Proc.new{|v,datum| DATA_TYPES(datum['data_type'])&.['validity'] || false },
                  'default_overridability' => 0
                },
                'data_type' => {
                  'required' => true,
                  'validity' = DATA_TYPES.keys,
                  'default_overridability' => 0
                },
                'enabled' => {
                  'required' => false,
                  'validity' => [true, false],
                  'default_overridability' => Proc.new{|v| v == false ? 0 : nil }
                }
              }
            }
          }
        } # end coverage_options/special_data/structure
      } # end coverage_options/special_data
    }, # end coverage_options
    'rules' => {
      'required' => false,
      'validity' => Proc.new{|v| v.class == ::Hash },
      'default_overridability' => nil,
      'default_value' => {},
      
      'special' => 'hash',
      'special_data' => {
        'structure' => {
          'code' => {
            'required' => true,
            'validity' => true, # WARNING: we skip validating code here but we really shouldn't
            'default_overridability' => 0
          }
        } # end rules/special_data/structure
      } # end rules/special_data
    } # end rules
  } # end configuration
  
  
  # Class Methods
  
  
  # Returns an (unsaved) IRC representing the combined IRC formed by merging the entire inheritance hierarchy for some configurable
  def self.get_inherited_irc(carrier_insurable_type, configurer, configurable)
    merge(get_hierarchy(carrier_insurable_type, configurer, configurable).map{|ircs| merge(ircs, true) }, false)
  end
  
  
  # Merge an array of IRCs together.
  # params:
  #   irc_array:              an array of IRCs
  #   common_override_level:  true to treat IRCs as having the same override level, false to treat them as having override levels equal to their indices
  # returns:
  #   an IRC representing the combination of all the IRCs in the array
  def self.merge(irc_array, common_override_level)
    # setup
    to_return = InsurableRateConfiguration.new(
      configurable_type: irc_array.drop(1).inject(irc_array.first&.configurable_type){|res,irc| break nil unless irc.configurable_type == res; res },
      configurable_id:   irc_array.drop(1).inject(irc_array.first&.configurable_id)  {|res,irc| break nil unless irc.configurable_id == res; res },
      configurer_type:   irc_array.drop(1).inject(irc_array.first&.configurer_type){|res,irc| break nil unless irc.configurer_type == res; res },
      configurer_id:     irc_array.drop(1).inject(irc_array.first&.configurer_id)  {|res,irc| break nil unless irc.configurer_id == res; res },
      carrier_info: {},
      coverage_options: [],
      rules: {}
    )
    # carrier info
    condemnation = nil # change to something like "__)C0nD3MN3d!!!<>(__" and do a "deep compact" after to avoid ambiguity in the meaning of nils
    to_return.carrier_info = irc_array.inject({}) do |combined, single|
      combined.deep_merge(single.carrier_info) do |k, v1, v2|
        # WARNING: no special support for arrays, since they aren't used right now
        v1 == v2 ? v1 : condemnation
      end
    end
    # configuration
    offsets = common_override_level ? 0 : [0...-1].map{|irc| irc.max_overridability }.inject([0]){|arr,mo| arr.concat(arr.last + mo + 1) }
    to_return.configuration = merge_data_structures(irc_array.map{|irc| irc.configuration }, CONFIGURATION_STRUCTURE, offsets)
    to_return.refresh_max_overridability
    # done
    return to_return
  end
  
  
  # Get the IRC inheritance hierarchy for a given configuration.
  # params:
  #   carrier_insurable_type: the CIT for which to pull IRCs (normally Residential Unit for MSI residential policies)
  #   configurer:             an account/agency/carrier
  #   configurable:           an InsurableGeographicalCategory or an insurable's CarrierInsurableProfile
  # returns:
  #   an array (ordered from least to most specific configurer) of arrays (ordered from least to most specific configurable) of IRCs
  def self.get_hierarchy(carrier_insurable_type, configurer, configurable)
    # get configurer and configurable hierarchies
    configurers = get_configurer_hierarchy(configurer, carrier_insurable_type.carrier)
    configurables = get_configurable_hierarchy(configurable)
    # get the insurable rate configurations
    to_return = ::InsurableRateConfiguration.where(configurer: configurers, configurable: configurables, carrier_insurable_type: carrier_insurable_type)
    # sort into hierarchy (i.e. array (ordered by configurer) of arrays (ordered by configurable))
    to_return = to_return.group_by{|irc| configurers.find_index{|c| irc.configurer_id == c.id && irc.configurer_type == c.class.name } }
      .sort_by{|configurable_index, ircs| configurable_index } # makes it into an array of [k,v] pairs
      .map{|val| val[1].sort_by{|irc| configurables.find_index{|c| irc.configurable_id == c.id && irc.configurable_type == c.class.name } } }
    # done
    return to_return
  end
  

  def self.postprocess_coverage_options(options)
    options.select{|uid,opt| opt['visible'] != false }
  end
  
  
  # Instance Methods
  
  def annotate_options(coverage_selections, coverage_options = self.configuration['coverage_options'], rules = self.configuration['rules'], deserialize_selections: true)
    # construct data hash
    data = {
      'overridability' => nil, # for the current rule's overridability level
      'coverage_options' => self.class.copy_with_deserialization(coverage_options),
      'coverage_selections' => deserialize_selections ? selections.replace(self.class.copy_with_deserialization(coverage_selections)) : self.class.copy_with_deserialization(coverage_selections)
    }
    # execute rules
    rules.values.sort{|a,b| (a['overridabilities_']['code'] || Float::INFINITY) <=> (a['overridabilities_']['code'] || Float::INFINITY) }.each do |rule|
      data['overridability'] = rule['overridabilities_']['code'] || Float::INFINITY
      begin
        execute(self.class.copy_with_deserialization(rule['code']), LANGUAGE, stack: [], data: data)
      rescue PseudoscriptError => pse
        puts "Pseudoscript Error Occurred: #{pse.message}" # otherwise ignore it, I suppose
      end
    end
    # w00t w00t
    return data['coverage_options']
  end
  
  def get_selection_errors(selections, options, use_titles: false)
    to_return = {}
    options.select{|uid,opt| opt['requirement'] == 'required' }.each do |opt|
      (to_return[uid] ||= []).push("selection cannot be blank") if selections[uid].nil? || !selections[uid]['selection']
    end 
    selections.select{|uid,sel| sel['selection'] }.each do |sel|
      next if options[uid].nil? # WARNING: for now we just ignore selections that aren't in the options...
      if options[uid].nil? || options[uid]['requirement'] == 'forbidden'
        (to_return[uid] ||= []).push("is not a valid coverage option")
      elsif sel['selection'] == true
        (to_return[uid] ||= []).push("selection cannot be blank") if options[uid]['options_type'] != 'none'
      else
        found = (options[uid]['options'] || {}).find{|opt| opt['data_type'] == sel['selection']['data_type'] && opt['value'] == sel['selection']['value'] }
        (to_return[uid] ||= []).push("has invalid selection '#{sel['selection']['value']}'") if found.nil? || found['enabled'] == false
      end
    end
    if use_titles
      to_return.transform_keys!{|uid| options[uid]&.[]('title') || selections[uid]&.[]('title') || 'Coverage Options #{uid}' }
    end
    return to_return
  end
  
  def self.automatically_select_options(options, selections = [], iterations: 1, rechoose_selection: Proc.new{|option,selection| option['requirement'] == 'required' ? (option['options_type'] == 'multiple_choice' ? option['options'].min{|a,b| a['enabled'] == false ? 1 : b['enabled'] == false ? -1 : a['value'].to_d <=> b['value'].to_d } : true) : nil })
    options.map do |uid, opt|
      sel = selections[uid]
      if opt['requirement'] == 'required'
        next [uid, { 'category' => opt['category'], 'selection' =>
          opt['options_type'] == 'none' ?
            true
            : opt['options'].blank? ?
              false
              : sel && sel['selection'] && opt['options'].any?{|o| o['data_type'] == sel['selection']['data_type'] && o['value'] == sel['selection']['value'] } ?
                sel['selection']
                : rechoose_selection.call(opt, sel)
        }]
      elsif opt['requirement'] == 'optional'
        if !sel || !sel['selection']
          next nil
        elsif opt['options_type'] == 'none'
          next [uid, { 'category' => opt['category'], 'selection' => true }]
        elsif opt['options_type'] == 'multiple_choice'
          if opt['options'].any?{|o| o['data_type'] == sel['selection']['data_type'] && o['value'] == sel['selection']['value'] }
            next [uid, sel]
          else
            next [uid, rechoose_selection.call(opt, sel)]
          end
        else
          next nil
        end
      else
        next nil
      end
    end.compact.to_h.compact#.map{|s| s['selection'] } was here in the original version (when it was an array, so need to incorporate uid if we want this)
  end

  
  private
    
  
    # Class Methods
  
    def self.get_configurer_hierarchy(configurer, carrier)
      to_return = [configurer]
      case configurer.class
        when ::Carrier
          # do nothing
        when ::Agency
          to_return.concat(configurer.agency_hierarchy(include_self: false) + [carrier])
        when ::Account
          to_return.concat(configurer.agency.agency_hierarchy(include_self: true) + [carrier])
      end
      return(to_return)
    end
    
    
    def self.get_configurable_hierarchy(configurable)
      to_return = []
      case configurable.class
        when ::CarrierInsurableProfile
          address = configurable.insurable.primary_address
          to_return = [configurable] + ::InsurableGeographicalCategory.where(state: nil)
            .or(::InsurableGeographicalCategory.where(state: address.state, counties: nil))
            .or(::InsurableGeographicalCategory.where(state: address.state).where('counties @> ARRAY[?]::varchar[]', address.county)
            .to_a.sort
        when ::InsurableGeographicalCategory
          to_return = ::InsurableGeographicalCategory.where(state: nil)
          unless configurable.state.nil?
            to_return = to_return.or(::InsurableGeographicalCategory.where(state: configurable.state, counties: nil))
            unless configurable.counties.blank?
              to_return = to_return.or(::InsurableGeographicalCategory.where(state: configurable.state).where('counties @> ARRAY[?]::varchar[]', configurable.counties))
            end
          end
          to_return = to_return.to_a.sort
      end
      return to_return
    end
    
    # Callbacks
    
    def refresh_max_overridability
      self.max_overridability = self.class.get_overridability_ceiling(self.configuration)
    end
    
    # Validations
    
    def validate_configuration
      error_hash = {}
      result = self.class.validate_data_structure(self.configuration, CONFIGURATION_STRUCTURE, errors: error_hash)
      self.configuration = result
      self.apply_errors_from_hash(error_hash)
    end
    
end



