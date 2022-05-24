
class InsurableRateConfiguration < ApplicationRecord

  include Structurable

  # ActiveRecord Associations
  
  belongs_to :configurable, polymorphic: true # Insurable or InsurableGeographicCategory (for now)
  belongs_to :configurer, polymorphic: true   # Account, Agency, or Carrier
  belongs_to :carrier_policy_type
  
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
  
  # Validations
  
  validate :validate_configuration
  
  # Structurable structures used in this model (and a helpful rule-to-text method)
  
  RULES_STRUCTURE = {
    'rules' => {
      'required' => false,
      'validity' => Proc.new{|v| v.class == ::Hash },
      'default_overridability' => nil,
      'default_value' => {},
      
      'special' => 'hash',
      'special_data' => {
        'structure' => {
          'subject' => {
            'required' => true,
            'validity' => Proc.new{|v| v.class == ::String },
            'default_overridability' => 0
          },
          'rule' => {
            'required' => true,
            'validity' => Proc.new do |v|
              next "must be a hash" unless v.class == ::Hash
              next v.each do |rule, params|
                case rule
                  when 'has_requirement'
                    break "has invalid requirement type '#{params}'" unless ['optional', 'required', 'forbidden'].include?(params)
                  when 'compares_fixed'
                    break "has invalid comparator '#{params['comparator']}'" unless ['=','<','>','<=','>='].include?(params['comparator'])
                    break "has invalid object '#{params['object']}' (expected a valid decimal number or a currency or percentage data type hash)" unless (BigDecimal(params['object'], 3) rescue false) || (params['object'].class == ::Hash && ['currency', 'percentage'].include?(params['object']['data_type']) && (BigDecimal(params['object']['value'], 3) rescue false))
                  when 'compares_coverage'
                    break "has invalid comparator '#{params['comparator']}'" if !['=','<','>','<=','>='].include?(params['comparator'])
                    break "has invalid object '#{params['object']}' (expected a string representing a coverage UID)" unless params['object'].class == ::String
                  when 'compares_percent'
                    break "has invalid comparator '#{params['comparator']}'" if !['=','<','>','<=','>='].include?(params['comparator'])
                    break "has invalid percent '#{params['percent']}' (expected a valid decimal number)" unless (BigDecimal(params['percent'], 3) rescue false)
                    break "has invalid object '#{params['object']}' (expected a string representing a coverage UID)" unless params['object'].class == ::String
                  when 'equal_to_fixed_or_percent'
                    break "has invalid fixed '#{params['fixed']}' (expected a valid decimal number or a currency or percentage data type hash)" unless (BigDecimal(params['fixed'], 3) rescue false) || (params['fixed'].class == ::Hash && ['currency', 'percentage'].include?(params['fixed']['data_type']) && (BigDecimal(params['fixed']['value'], 3) rescue false))
                    break "has invalid percent '#{params['percent']}' (expected a valid decimal number)" unless (BigDecimal(params['percent'], 3) rescue false)
                    break "has invalid object '#{params['object']}' (expected a string representing a coverage UID)" unless params['object'].class == ::String
                  when 'greatest_of_fixed_or_percent'
                    break "has invalid fixed '#{params['fixed']}' (expected a valid decimal number or a currency or percentage data type hash)" unless (BigDecimal(params['fixed'], 3) rescue false) || (params['fixed'].class == ::Hash && ['currency', 'percentage'].include?(params['fixed']['data_type']) && (BigDecimal(params['fixed']['value'], 3) rescue false))
                    break "has invalid percent '#{params['percent']}' (expected a valid decimal number)" unless (BigDecimal(params['percent'], 3) rescue false)
                    break "has invalid object '#{params['object']}' (expected a string representing a coverage UID)" unless params['object'].class == ::String
                  else
                    break "includes invalid rule type '#{rule}'"
                end
              end
            end,
            'default_overridability' => 0
          },
          'condition' => {
            'required' => true,
            'validity' => Proc.new do |v,datum|
              v == true || (v.class == ::Hash && (
                v.has_key?('coverage_selected') || v.has_key?('coverage_not_selected') # this is the only condition type supported right now
              ))
            end,
            'default_overridability' => 0
          }
        } # end rules/special_data/structure
      } # end rules/special_data
    } # end rules
  }
  
  def self.rule_to_text(rule, coverage_options)
    begin
      to_return = ""
      # add in condition(s)
      to_return += "if " + rule['condition'].map do |cond_type, params|
        case cond_type
          when 'coverage_selected'
            "#{(params.class == ::Array ? params : [params]).map{|param| coverage_options[param]&.[]('title') || "Coverage Option #{params}" }.join(" and ")} #{params.class == ::Array && params.length > 1 ? 'are' : 'is'} selected"
          when 'coverage_not_selected'
            "#{(params.class == ::Array ? params : [params]).map{|param| coverage_options[param]&.[]('title') || "Coverage Option #{params}" }.join(" and ")} #{params.class == ::Array && params.length > 1 ? 'are' : 'is'} not selected"
          else
            throw 'fail'
        end
      end.compact.join(" and ") + " then "
      # get subject
      subject = coverage_options[rule['subject']]
      subject_title = subject&.[]('title') || "Coverage Option #{rule['subject']}"
      # add in rule body
      to_return += rule['rule'].map do |rule_type, params|
        case rule_type
          when 'has_requirement'
            "#{subject_title} must be #{params}"
          when 'compares_fixed'
            object = if params['object'].class != ::Hash
              BigDecimal(params['object'], 3).to_s("F")
            else
              case params['object']['data_type']
                when 'currency'
                  "$#{(BigDecimal(params['object']['value'], 2).to_s("F") + "00")[ /.*\..{2}/ ]}"
                when 'percentage'
                  "#{BigDecimal(params['object']['value'], 3).to_s("F")}%"
                else
                  throw 'fail'
              end
            end
            "#{subject_title} must be #{params['comparator']} #{rule_type} #{object}"
          when 'compares_coverage'
            object = coverage_options[params['object']]&.[]('title') || "Coverage option #{params['object']}"
            "#{subject_title} must be #{params['comparator']} #{rule} #{object}"
          when 'compares_percent'
            object = coverage_options[params['object']]&.[]('title') || "Coverage option #{params['object']}"
            percent = "#{BigDecimal(params['percent'], 3).to_s("F")}%"
            "#{subject_title} must be #{params['comparator']} #{percent} of #{object}"
          when 'equal_to_fixed_or_percent'
            fixed = if params['fixed'].class != ::Hash
              BigDecimal(params['fixed'], 3).to_s("F")
            else
              case params['fixed']['data_type']
                when 'currency'
                  "$#{(BigDecimal(params['fixed']['value'], 2).to_s("F") + "00")[ /.*\..{2}/ ]}"
                when 'percentage'
                  "#{BigDecimal(params['fixed']['value'], 3).to_s("F")}%"
                else
                  throw 'fail'
              end
            end
            object = coverage_options[params['object']]&.[]('title') || "Coverage option #{params['object']}"
            percent = "#{BigDecimal(params['percent'], 3).to_s("F")}%"
            "#{subject_title} must = #{fixed} or #{percent} of ##{object}"
          when 'greatest_of_fixed_or_percent'
            fixed = if params['fixed'].class != ::Hash
              BigDecimal(params['fixed'], 3).to_s("F")
            else
              case params['fixed']['data_type']
                when 'currency'
                  "$#{(BigDecimal(params['fixed']['value'], 2).to_s("F") + "00")[ /.*\..{2}/ ]}"
                when 'percentage'
                  "#{BigDecimal(params['fixed']['value'], 3).to_s("F")}%"
                else
                  throw 'fail'
              end
            end
            object = coverage_options[params['object']]&.[]('title') || "Coverage option #{params['object']}"
            percent = "#{BigDecimal(params['percent'], 3).to_s("F")}%"
            "#{subject_title} must = the greater of #{fixed} or #{percent} of ##{object}"
          else
            throw 'fail'
        end
      end.map.with_index{|strang, ind| ind == 0 ? strang : ind == rule['rule'].length - 1 ? ", and #{strang}" : ", #{strang}" }.join("")
    rescue
      return nil
    end
    # tweak syntax, and done!
    return to_return.capitalize
  end
  
  CRITICAL_SUBSTRUCTURE = {
    'title' => {
      'required' => true,
      'validity' => Proc.new{|v| v.class == ::String },
      'default_overridability' => 0
    },
    'visible' => {
      'required' => true,
      'validity' => [true, false],
      'union' => Proc.new{|ancient, noob| ancient || noob },
      'default_overridability' => 0,
      'default_value' => true
    },
    'requirement' => {
      'required' => true,
      'validity' => ['optional', 'required', 'forbidden'],
      'union' => Proc.new{|ancient, noob| ['required', 'forbidden'].find{|x| ancient == x || noob == x } || 'optional' },
      'default_overridability' => Proc.new{|v| v == 'optional' ? nil : 0 }
    },
    'options_type' => {
      'required' => true,
      'validity' => ['multiple_choice', 'none'],
      'union' => Proc.new{|ancient, noob| ancient == 'multiple_choice' ? ancient : noob },
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
            'validity' => Proc.new do |v,datum|
              case datum['data_type']
                when 'currency'; (Integer(v) rescue -1) >= 0 ? true : false
                when 'percentage';  (BigDecimal(v) rescue -1) >= 0 ? true : false
                else; false
              end
            end,
            'default_overridability' => 0
          },
          'data_type' => {
            'required' => true,
            'validity' => ['currency', 'percentage'],
            'default_overridability' => 0
          }
        }
      }
    }
  }

  QBE_STRUCTURE = {
    'coverage_options' => {
      'required' => false,
      'validity' => Proc.new{|v| v.class == ::Hash },
      'default_overridability' => 0,
      'default_value' => {},
    
      'special' => 'hash',
      'special_data' => {
        'structure' => {
          'schedule' => {
            'required' => true,
            'validity' => ['coverage_c', 'liability', 'optional', 'liability_only'],
            'default_overridability' => 0
          },
          'sub_schedule' => {
            'required' => true,
            'validity' => Proc.new{|v| v.nil? || v.class == ::String },
            'default_overridability' => 0
          },
          'category' => {
            'required' => true,
            'validity' => ['limit', 'deductible', 'option'],
            'default_overridability' => 0 
          }
        }.merge(CRITICAL_SUBSTRUCTURE) # end coverage_options/special_data/structure
      } # end coverage_options/special_data
    } # end coverage_options
  }.merge({
    'rules' => {
      'required' => false,
      'validity' => Proc.new{|v| v.class == ::Hash },
      'default_overridability' => nil,
      'default_value' => {},
      
      'special' => 'hash',
      'special_data' => {
        'structure' => {
          'subject' => {
            'required' => true,
            'validity' => true,
            'default_overridability' => 0
          },
          'rule' => {
            'required' => true,
            'validity' => true,
            'default_overridability' => 0
          },
          'condition' => {
            'required' => true,
            'validity' => true,
            'default_overridability' => 0
          }
        }
      }
    }
  })

  MSI_STRUCTURE = {
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
          'description' => {
            'required' => false,
            'validity' => Proc.new{|v| v.nil? || v.class == ::String },
            'default_overridability' => Proc.new{|v,uid,data,irc| v.nil? ? nil : 0 }
          }
        }.merge(CRITICAL_SUBSTRUCTURE) # end coverage_options/special_data/structure
      } # end coverage_options/special_data
    }
  }.merge({
    'rules' => {
      'required' => false,
      'validity' => Proc.new{|v| v.class == ::Hash },
      'default_overridability' => nil,
      'default_value' => {},
      
      'special' => 'hash',
      'special_data' => {
        'structure' => {
          'subject' => {
            'required' => true,
            'validity' => true,
            'default_overridability' => 0
          },
          'rule' => {
            'required' => true,
            'validity' => true,
            'default_overridability' => 0
          },
          'condition' => {
            'required' => true,
            'validity' => true,
            'default_overridability' => 0
          }
        }
      }
    }
  })
    
=begin
    , # end coverage_options
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
=end  
  
  # Class Methods
  
  
  # Returns an (unsaved) IRC representing the combined IRC formed by merging the entire inheritance hierarchy for some configurable
  def self.get_inherited_irc(carrier_policy_type, configurer, configurable, agency: nil, exclude: nil, union_mode: false, &blck)
    # Alternative: merge(get_hierarchy(carrier_policy_type, configurer, configurable, agency: agency).map{|ircs| merge(ircs, true) }, false)... but this won't work in union_mode since it stores arrays of all encountered values
    hierarchy = get_hierarchy(carrier_policy_type, configurer, configurable, agency: agency, exclude: exclude, union_mode: union_mode, &blck)
    if union_mode
      # do a union merge of all the children
      unionized = cull_hierarchy!(copy_hierarchy(hierarchy), :parents_inclusive_all, configurer, configurable, preserve_empties: true) # cut out all IRCs for configurables >= configurable, leaving only children; preserve empties so if a configurer's entires are all destroyed, we still assign the same overridability offsets
      unionized = merge(unionized.flatten, unionized.map.with_index{|ircs, index| ircs.map{|irc| index } }.flatten, union_mode: true)
      # do an intersection merge of all the parents
      intersectional = cull_hierarchy!(hierarchy, :children_exclusive_all, configurer, configurable, preserve_empties: true)
      intersectional = merge(intersectional.flatten, intersectional.map.with_index{|ircs, index| ircs.map{|irc| index } }.flatten, union_mode: false)
      # do an intersection merge of the two boyos we got, with no offsets (they retain overridability numbers as determined during the previous merges)
      merge([intersectional, unionized], [0, 0], union_mode: false)
    else
      merge(hierarchy.flatten, hierarchy.map.with_index{|ircs, index| ircs.map{|irc| index } }.flatten, union_mode: false)
    end
  end
  
  
  # Merge an array of IRCs together.
  # params:
  #   irc_array:          an array of IRCs
  #   override_level:     true to treat IRCs as having the same override level, false to treat them as having override levels equal to their indices, array of integers to provide explicit offsets
  # returns:
  #   an IRC representing the combination of all the IRCs in the array
  def self.merge(irc_array, override_level, union_mode: false)
    # setup
    to_return = InsurableRateConfiguration.new(
      configurable_type: irc_array.drop(1).inject(irc_array.first&.configurable_type){|res,irc| break nil unless irc.configurable_type == res; res },
      configurable_id:   irc_array.drop(1).inject(irc_array.first&.configurable_id)  {|res,irc| break nil unless irc.configurable_id == res; res },
      configurer_type:   irc_array.drop(1).inject(irc_array.first&.configurer_type){|res,irc| break nil unless irc.configurer_type == res; res },
      configurer_id:     irc_array.drop(1).inject(irc_array.first&.configurer_id)  {|res,irc| break nil unless irc.configurer_id == res; res },
      carrier_info: {},
      rates: {}
    )
    # carrier info
    condemnation = nil # change to something like "__)C0nD3MN3d!!!<>(__" and do a "deep compact" after to avoid ambiguity in the meaning of nils
    to_return.carrier_info = irc_array.inject({}) do |combined, single|
      combined.deep_merge(single.carrier_info) do |k, v1, v2|
        # WARNING: no special support for arrays, since they aren't used right now
        v1 == v2 ? v1 : (v1.nil? ^ v2.nil?) ? (v1 || v2) : condemnation
      end
    end
    # rates
    to_return.rates = (override_level == true || override_level == false ? irc_array.reverse : irc_array.sort_by.with_index{|v,i| -override_level[i] }).find{|irc| !irc.rates.blank? && !irc.rates['rates'].blank? && !irc.rates['rates'].all?{|v| v.blank? } }&.rates || {}
    # configuration
    offsets = override_level.class == ::Array ? override_level : override_level ? 0 : [0...-1].map{|irc| irc.max_overridability(refresh: true) }.inject([0]){|arr,mo| arr.concat(arr.last + mo + 1) }
    to_return.configuration = merge_data_structures(irc_array.map{|irc| irc.configuration }, irc_array.find{|irc| !irc.carrier_policy_type.nil? }&.carrier_policy_type&.carrier_id == 1 ? QBE_STRUCTURE : MSI_STRUCTURE, offsets, union_mode: union_mode)
    to_return.max_overridability(refresh: true)
    # done
    return to_return
  end
  
  
  # Get the IRC inheritance hierarchy for a given configuration.
  # params:
  #   carrier_policy_type:    the CPT for which to pull IRCs
  #   configurer:             an account/agency/carrier
  #   configurable:           an InsurableGeographicalCategory or an insurable
  #   agency:                 (optional) if configurer is an account, you can provide an agency to use instead of configurer.agency if desired
  #   blck:                   (optional) a block for extra culling; will be called with IRC as parameter, returns true to keep, false to discard
  # returns:
  #   an array (ordered from least to most specific configurer) of arrays (ordered from least to most specific configurable) of IRCs
  def self.get_hierarchy(carrier_policy_type, configurer, configurable, agency: nil, exclude: nil, union_mode: false, &blck)
    # get configurer and configurable hierarchies
    configurers = get_configurer_hierarchy(configurer, carrier_policy_type.carrier, agency: agency)
    configurables = get_configurable_hierarchy(configurable, union_mode: union_mode)
    # get the insurable rate configurations
    to_return = ::InsurableRateConfiguration.where(configurer: configurers, configurable: configurables, carrier_policy_type: carrier_policy_type).to_a
    to_return.select! &blck unless blck.nil?
    # sort into hierarchy (i.e. array (ordered by configurer) of arrays (ordered by configurable))
    to_return = to_return.group_by{|irc| configurers.find_index{|c| irc.configurer_id == c.id && irc.configurer_type == c.class.name } }
      .sort_by{|configurable_index, ircs| configurable_index } # makes it into an array of [k,v] pairs
      .map{|val| val[1].sort_by{|irc| configurables.find_index{|c| irc.configurable_id == c.id && irc.configurable_type == c.class.name } } }
    # handle exclusions
    cull_hierarchy!(to_return, exclude, configurer, configurable) if exclude # optimize away some culling runs since exclude is usually nil
    # done
    return to_return
  end
  
  # Takes an IRC hierarchy (i.e. [ [ircs for top configurer, ordered from least to most specific configurable], [ircs for next configurer], ...]) and culls entries based on an exclusion rule.
  # Mutates the hierarchy directly rather than returning a modified version. Also returns the modified hierarchy.
  # The available exclusion rules are:
  #   configurer:             removes the entries for a particular configurer
  #   configurable:           removes the entries for a particular configurable
  #   exact_match:            removes the entries for a particular configurer/configurable pair
  #   chilren_inclusive:      removes entries for the given configurer and any children of the given configurable, including the given configurable itself
  #   chilren_exclusive:      removes entries for the given configurer and any children of the given configurable, excluding the given configurable itself
  #   chilren_inclusive_all:  removes entries for all configurers for any children of the given configurable, including the given configurable itself
  #   chilren_exclusive_all:  removes entries for all configurers for any children of the given configurable, excluding the given configurable itself
  #   parent_...:             same as children rules, except culls parents
  def self.cull_hierarchy!(hierarchy, exclude, configurer, configurable, preserve_empties: false)
    configurer_indices_to_kill = []
    case exclude
      when :configurer
        configurer_index = hierarchy.find_index{|entries| entries.first&.configurer == configurer }
        configurer_indices_to_kill.push(configurer_index) unless configurer_index.nil?
      when :configurable
        hierarchy.select!{|arr| arr.select!{|val| val.configurable != configurable }; preserve_empties || !arr.blank? }
      when :exact_match
        configurer_index = hierarchy.find_index{|entries| entries.first&.configurer == configurer }
        if configurer_index
          hierarchy[configurer_index].select!{|val| val.configurable != configurable }
          configurer_indices_to_kill.push(configurer_index) if hierarchy[configurer_index].blank?
        end
      when :children_inclusive, :children_exclusive, :children_inclusive_all, :children_exclusive_all,
           :parents_inclusive, :parents_exclusive, :parents_inclusive_all, :parents_exclusive_all
        for_all = [:children_inclusive_all, :children_exclusive_all, :parents_inclusive_all, :parents_exclusive_all].include?(exclude)
        parent_mode = [:parents_inclusive, :parents_exclusive, :parents_inclusive_all, :parents_exclusive_all].include?(exclude)
        exclusive_mode = [:children_exclusive, :children_exclusive_all, :parents_exclusive, :parents_exclusive_all].include?(exclude)
        configurer_index = (for_all ? 0 : hierarchy.find_index{|entries| entries.first&.configurer == configurer }) # if not for all, apply only to the configurer itself if present; if for all, apply to all
        if configurer_index
          stop_configurer_index = (for_all ? hierarchy.length : configurer_index + 1)
          while configurer_index < hierarchy.length
            # grab irc array
            entries = hierarchy[configurer_index]
            configurer_index += 1
            # get the index of IRC for the given configurable, or for the first one past it
            index = case configurable
              when ::InsurableGeographicalCategory
                entries.find_index{|val| (val.configurable <=> configurable) >= 0 }
              else
                (entries.last&.configurable == configurable) ? entries.length - 1 : nil # if not an IGC it must be the last entry since it will have no children
            end
            # chop out the children/parents
            unless index.nil?
              if exclusive_mode && entries[index].configurable == configurable
                index += (parent_mode ? -1 : 1) # if we're exclusive, make sure we don't kill our target itself
              elsif parent_mode
                index -= 1 # if configurables don't match, the configurable itself isn't in the list and we have the index of its first CHILD; so back up 1 step to go to the first PARENT
              end
              if (parent_mode ? (index == entries.length - 1) : (index == 0))
                entries.clear
                configurer_indices_to_kill.push(configurer_index)
              else
                if parent_mode
                  entries.shift(index + 1)
                else
                  entries.pop(entries.length - index)
                end
              end
            end
          end # end while
        end # end if configurer_index
    end
    hierarchy.select!.with_index{|entries, configurer_index| !configurer_indices_to_kill.include?(configurer_index) } unless preserve_empties
    return hierarchy
  end
  
  def self.copy_hierarchy(hierarchy)
    hierarchy.map{|harr| harr.clone } # clone arrays of ircs
  end
  
  # Instance Methods
    
  def max_overridability(refresh: true)
    @max_overridability = nil if refresh
    @max_overridability ||= self.class.get_overridability_ceiling(self.configuration)
  end
  
  def annotate_options(
    coverage_selections,
    coverage_options = self.configuration['coverage_options'], rules = self.configuration['rules'], rule_overridabilities = self.configuration['overridabilities_']&.[]('rules') || {}, deserialize_selections: true)
    # WARNING: should be no need to do this for now... we handle the cases in the body, which is irritating. # ensure values are deserialized
    #coverage_options = self.class.copy_with_deserialization(coverage_options)
    #coverage_selections = deserialize_selections ? selections.replace(self.class.copy_with_deserialization(coverage_selections)) : self.class.copy_with_deserialization(coverage_selections)
    # execute rules
    (rules || {}).to_a.sort{|a,b| (rule_overridabilities[a[0]] || Float::INFINITY) <=> (rule_overridabilities[b[0]] || Float::INFINITY) }.each do |rule_pair|
      rule = rule_pair[1]
      subject = coverage_options[rule['subject']]
      next unless subject
      overridability = rule_overridabilities[rule_pair[0]] || Float::INFINITY
      condition_satisfied =  rule['condition'] == true || (rule['condition'].class == ::Hash && rule['condition'].all? do |cond, params|
        case cond
          when 'coverage_selected'
            (params.class == ::Array ? params : [params]).all?{|uid| coverage_selections[uid] && coverage_selections[uid]['selection'] }
          when 'coverage_not_selected'
            (params.class == ::Array ? params : [params]).all?{|uid| !coverage_selections[uid] || !coverage_selections[uid]['selection'] }
          else
            false
        end
      end)
      if condition_satisfied
        rule['rule'].each do |rule_type, params|
          case rule_type # MOOSE WARNING: institute overridability checks, bub!
            when 'has_requirement'
              subject['requirement'] = params
            when 'compares_fixed', 'compares_coverage', 'compares_percent'
              # get the object
              object = case rule_type
                when 'compares_fixed';      (params.class == ::Hash ? { 'data_type' => params['data_type'], 'value' => BigDecimal(params['value'], 3) } : BigDecimal(params, 3) rescue false)
                when 'compares_coverage';   coverage_selections[params['object']]['selection']
                when 'compares_percent';    ({ 'data_type' => coverage_selections[params['object']]['selection']['data_type'], 'value' => (BigDecimal(coverage_selections[params['object']]['selection']['value'], 3) * BigDecimal(params['percent'], 3) / 100.to_d).truncate(coverage_selections[params['object']]['selection']['data_type'] == 'currency' ? 0 : 3) } rescue false)
              end
              next if object == false
              required_data_type = (object.is_a?(::Hash) ? object['data_type'] : nil)
              object = (object.is_a?(::Hash) ? object['value'] : object)
              # filter the options
              subject['options'] = subject['options'].select do |opt|
                next true if required_data_type && required_data_type != opt['data_type']
                next (opt['data_type'] == 'currency' ? Integer(opt['value']) : BigDecimal(opt['value'], 3)).send(params['comparator'] == '=' ? '==' : params['comparator'], object)
              end if subject['options']
            when 'equal_to_fixed_or_percent', 'greatest_of_fixed_or_percent'
              # get the fixed and the object
              fixed = (params['fixed'].class == ::Hash ? { 'data_type' => params['fixed']['data_type'], 'value' => BigDecimal(params['fixed']['value'], 3) } : BigDecimal(params['fixed'], 3) rescue false)
              fixed_required_data_type = (fixed.class == ::Hash ? fixed['data_type'] : nil)
              fixed = (fixed.class == ::Hash ? fixed['value'] : fixed)
              object = ({ 'data_type' => coverage_selections[params['object']]['selection']['data_type'], 'value' => (BigDecimal(coverage_selections[params['object']]['selection']['value'], 3) * BigDecimal(params['percent'], 3) / 100.to_d).truncate(coverage_selections[params['object']]['selection']['data_type'] == 'currency' ? 0 : 3) } rescue false)
              next if fixed == false || object == false
              required_data_type = (object.is_a?(::Hash) ? object['data_type'] : nil)
              object = (object.is_a?(::Hash) ? object['value'] : object)
              # filter the options
              subject['options'] = subject['options'].select do |opt|
                opt_value = (opt['data_type'] == 'currency' ? Integer(opt['value']) : BigDecimal(opt['value'], 3))
                case rule_type
                  when 'equal_to_fixed_or_percent'
                    next ((fixed_required_data_type.nil? || opt['data_type'] == fixed_required_data_type) && fixed == opt_value) ||
                         ((required_data_type.nil? || opt['data_type'] == required_data_type) && object == opt_value)
                  when 'greatest_of_fixed_or_percent'
                    next [[fixed_required_data_type, fixed], [required_data_type, object]].select{|v| v[0].nil? || v[0] == opt['data_type'] }.max{|a,b| a[1] <=> b[1] }[1] == opt_value
                  else
                    next true
                end
              end if subject['options']
          end
        end
      end
    end
    # w00t w00t
    return coverage_options
  end
  
  # insert_invisible_requirements will insert visible == false, requirement == 'required' options into the selections hash;
  # it is assumed that these will all have 'options_type' == 'none'; if some are 'multiple_choice', pass insert_invisible_requirements a hash mapping their UIDs to the desired selections. Otherwise, it will pick the first option automatically
  def get_selection_errors(selections, options = annotate_options(selections), use_titles: false, insert_invisible_requirements: true)
    to_return = {}
    options.select{|uid,opt| opt['requirement'] == 'required' }.each do |uid, opt|
      if !selections[uid] || !selections[uid]['selection']
        if opt['visible'] == false && insert_invisible_requirements
          selections[uid] ||= {}
          selections[uid]['selection'] = case opt['options_type']
            when 'multiple_choice'
              if insert_invisible_requirements.class == ::Hash  && insert_invisible_requirements.has_key?(uid)
                insert_invisible_requirements[uid]
              else
                opt['options'].first
              end
            else
              true
          end
        else
          (to_return[uid] ||= []).push("is required")
        end
      end
    end 
    selections.select{|uid,sel| sel }.each do |uid, sel|
      #next if options[uid].nil? # WARNING: for now we just ignore selections that aren't in the options... NOPE, RESTORED ERROR. But left this here because I don't remember why it was here to begin with
      if options[uid].nil? || options[uid]['requirement'] == 'forbidden'
        (to_return[uid] ||= []).push("is not a valid coverage option")
      elsif sel['selection'] == true
        (to_return[uid] ||= []).push("selection cannot be blank") if options[uid]['options_type'] != 'none'
      else
        found = (options[uid]['options'] || {}).find{|opt| opt['data_type'] == sel['selection']['data_type'] && opt['value'] == sel['selection']['value'] }
        (to_return[uid] ||= []).push("has invalid selection '#{sel['selection']['value']}'") if found.nil?
      end
    end
    if use_titles
      to_return.transform_keys!{|uid| options[uid]&.[]('title') || 'Coverage Option #{uid}' }
    end
    return to_return
  end
  
  def self.automatically_select_options(options, selections = {}, iterations: 1, rechoose_selection: Proc.new{|option,selection| option['requirement'] == 'required' ? (option['options_type'] == 'multiple_choice' ? option['options'].min{|a,b| a['value'].to_d <=> b['value'].to_d } : true) : nil })
    options.map do |uid, opt|
      sel = selections[uid]&.[]('selection')
      if opt['requirement'] == 'required'
        next [uid,
          opt['options_type'] == 'none' ?
            true
            : opt['options'].blank? ?
              false
              : sel && sel != true && opt['options'].any?{|o| o['data_type'] == sel['data_type'] && o['value'] == sel['value'] } ?
                sel
                : rechoose_selection.call(opt, sel)
        ]
      elsif opt['requirement'] == 'optional'
        if !sel
          next nil
        elsif opt['options_type'] == 'none'
          next [uid, true ]
        elsif opt['options_type'] == 'multiple_choice'
          if sel != true && opt['options'].any?{|o| o['data_type'] == sel['data_type'] && o['value'] == sel['value'] }
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
    end.compact.to_h.compact.transform_values{|v| { 'selection' => remove_overridability_data!(v) } }
  end

  
  def self.get_coverage_options(*largs, **kargs, &blck)
    result = true_get_coverage_options(*largs, **kargs, &blck)
    if result == :retry
      result = true_get_coverage_options(*largs, **kargs, on_repeat: 1, &blck)
    end
    return result
  end
  
  def self.true_get_coverage_options(carrier_policy_type, insurable, selections, effective_date, additional_insured_count, billing_strategy,                 # required data
                                eventable: nil, perform_estimate: true, estimate_default_on_billing_strategy_code_failure: :min,                        # execution options (note: perform_estimate should be 'final' instead of true for QBE, if you want to trigger a getMinPrem request)
                                add_selection_fields: false,
                                additional_interest_count: nil, agency: nil, account: insurable.class == ::Insurable ? insurable.account : nil,         # optional/overridable data
                                nonpreferred_final_premium_params: nil,                                                                                 # special optional data
                                on_retry: 0)                                                                                                            # used by system to tell method whether it's already retrying
    # clean up params info
    billing_strategy_carrier_code = billing_strategy.carrier_code
    unit = nil
    if insurable.class == ::Insurable && !::InsurableType::COMMUNITIES_IDS.include?(insurable.insurable_type_id)
      unit = insurable
      insurable = insurable.parent_community
    end
    cip = (insurable.class != ::Insurable ? nil : insurable.carrier_profile(carrier_policy_type.carrier_id))
    irc_filter_block = nil
    # perform prep
    if carrier_policy_type.carrier_id == ::QbeService.carrier_id && insurable.class == ::Insurable
      # ensure we're prepared
      error = qbe_prepare_for_get_coverage_options(insurable, cip, additional_insured_count + 1, effective_date, traits_override: nonpreferred_final_premium_params, force_address_specific_rates: (eventable.class == ::PolicyQuote))
      if error.blank?
        # add irc filter block to ensure we only use IRCs with rates for the right insurable traits
        cip = (insurable.class != ::Insurable ? nil : insurable.carrier_profile(carrier_policy_type.carrier_id)) if cip.nil?
        applicability = QbeService.get_applicability(insurable, nonpreferred_final_premium_params || {}, cip: cip.reload)
        irc_filter_block = Proc.new{|irc| irc.configurable_type != 'Insurable' || irc.configurable_id != insurable.id || irc.configurer_type != 'Carrier' || irc.configurer_id != ::QbeService.carrier_id || irc.rates['applicability'] == applicability }
      else
        return {
          valid: false,
          coverage_options: {},
          estimated_premium: nil,
          estimated_installment: nil,
          estimated_first_payment: nil,
          installment_fee: 0,
          errors: { internal: "qbe_prepare_for_get_coverage_options returned error '#{error}'", external: I18n.t(error), special: error == "insurable_rate_configuration.qbe.county_failure" ? "county_resolution_failure" : nil },
          annotated_selections: {}
        }.merge(eventable.class != ::PolicyQuote ? {} : {
          msi_data: nil,
          event: nil
        })
      end
    end
    # get coverage options and selection errors
    selections = selections.select{|uid, sel| sel && sel['selection'] }
    irc = get_inherited_irc(carrier_policy_type, account || agency || carrier_policy_type.carrier, insurable, agency: agency, &irc_filter_block)
    coverage_options = irc.annotate_options(selections)
    selection_errors = irc.get_selection_errors(selections, coverage_options, insert_invisible_requirements: true)
    valid = selection_errors.blank?
    estimated_premium_error = valid ? nil : { internal: selection_errors.to_s, external: selection_errors.select{|uid| coverage_options[uid] }.map{|uid,errz| errz.map{|errz| "#{coverage_options[uid]['title']} #{errz}" }.join("; ") }.join("; ") }
    # initialize premium numbers variables unnecessarily
    estimated_premium = nil
    estimated_installment = nil
    estimated_first_payment = nil
    policy_fee = nil
    # perform the estimate, if requested
    if perform_estimate
      case carrier_policy_type.carrier_id
        when ::MsiService.carrier_id
          # fix up selections and get preferred status
          selections = automatically_select_options(coverage_options, selections) unless valid
          preferred = (unit || insurable).class == ::Insurable && (unit || insurable).get_carrier_status(carrier_policy_type.carrier_id) == :preferred
          # prepare the call
          msis = MsiService.new
          result = msis.build_request(:final_premium,
            effective_date: effective_date || (Time.current.to_date + 1.day), 
            additional_insured_count: additional_insured_count,
            additional_interest_count: additional_interest_count || (insurable.class == ::Insurable && (!insurable.account_id.nil? || !insurable.parent_community&.account_id.nil?) ? 1 : 0),
            coverages_formatted:  selections.map do |uid, sel|
                                    next nil unless sel && sel['selection']
                                    covopt = coverage_options[uid]
                                    next nil unless covopt
                                    next { CoverageCd: uid }.merge(sel['selection'] == true ? {} : {
                                      (covopt['category'] == 'deductible' ? :Deductible : :Limit) => { Amt: BigDecimal(sel['selection']['value']) / 100.to_d } # same whether sel['selection']['data_type'] is 'percentage' or 'currency', since currency stores number of cents
                                    })
                                  end.compact,
            **(preferred ?
                { community_id: cip.external_carrier_id }
                : { address: insurable.primary_address }.merge((nonpreferred_final_premium_params || {}).compact)
            ).merge({ line_breaks: true })
          )
          event = ::Event.new(msis.event_params.merge(eventable: eventable))
          if !result
            # failed to get final premium
            valid = false
            estimated_premium_error = { internal: msis.errors.to_s, external: "Unknown error occurred" } if estimated_premium_error.blank? # error before making the call
          else
            # make the call
            event.request = msis.compiled_rxml
            event.save
            event.started = Time.now
            result = msis.call
            event.completed = Time.now
            event.response = result[:response].response.body
            event.status = result[:error] ? 'error' : 'success'
            event.save
            # handle the result
            if result[:error]
              valid = false
              if estimated_premium_error.blank?
                msg = result[:external_message].to_s
                estimated_premium_error = {
                  internal: "#{result[:external_message].to_s}#{result[:extended_external_message].blank? ? "" : "\n\n #{result[:extended_external_message]}"}",
                  external: MsiService.displayable_error_for(result[:external_message].to_s, result[:extended_external_message]) || "Error calculating premium"
                }
              end
            else
              # total premium
              policy_fee = ((result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy", "MSI_PolicyFee", 'Amt') || 0).to_d * 100).to_i
              estimated_premium = [result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy", "PaymentPlan")].flatten
                                              .map do |plan|
                                                [
                                                  plan["PaymentPlanCd"],
                                                  plan["MSI_TotalPremiumAmt"]["Amt"]
                                                ]
                                              end.to_h
              estimated_premium = estimated_premium[billing_strategy_carrier_code].to_d || estimated_premium.values.send(estimate_default_on_billing_strategy_code_failure).to_d
              estimated_premium = (estimated_premium * 100).ceil # put it in cents
              if(billing_strategy_carrier_code == 'Annual')
                estimated_installment = estimated_premium
                estimated_first_payment = 0
              else
                # installment
                estimated_installment = [result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy", "PaymentPlan")].flatten
                                                .map do |plan|
                                                  [
                                                    plan["PaymentPlanCd"],
                                                    plan["MSI_InstallmentAmount"]["Amt"]
                                                  ]
                                                end.to_h
                estimated_installment = estimated_installment[billing_strategy_carrier_code].to_d || estimated_installment.values.send(estimate_default_on_billing_strategy_code_failure).to_d
                estimated_installment = (estimated_installment * 100).ceil # put it in cents
                # first payment
                estimated_first_payment = [result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy", "PaymentPlan")].flatten
                                                .map do |plan|
                                                  [
                                                    plan["PaymentPlanCd"],
                                                    plan["MSI_DownPaymentAmount"]["Amt"]
                                                  ]
                                                end.to_h
                estimated_first_payment = estimated_first_payment[billing_strategy_carrier_code].to_d || estimated_first_payment.values.send(estimate_default_on_billing_strategy_code_failure).to_d
                estimated_first_payment = (estimated_first_payment * 100).ceil # put it in cents
              end
            end # msi result handling (starts at if result[:error])
          end # event handling (starts at if !result)
        when ::QbeService.carrier_id
          interval = { 'FL' => 'annual', 'SA' => 'bi_annual', 'QT' => 'quarter', 'QBE_MoRe' => 'month' }[billing_strategy_carrier_code]
          # try to fix things if our irc is missing info the qbe prepare method already verified that it has (should be because there are duplicate IRCs and one is missing data)
          if on_retry == 0 && (irc&.rates&.[]('rates')&.[](additional_insured_count.to_i + 1)&.[](interval).blank? rescue false)
            ircs = ::InsurableRateConfiguration.where(configurable: irc.configurable, configurer: irc.configurer, carrier_policy_type_id: irc.carrier_policy_type_id).select{|i| irc_filter_block.call(i) }
            if ircs.count > 1
              survivor = ircs.max{|i| i.created_at }
              ircs.each{|i| i.delete unless i == survivor }
              return :retry
            end
          end
          # perform approximation using rates
          selected_rates = irc.rates['rates'][additional_insured_count + 1][interval].select do |rate|
            if rate['sub_schedule'] == 'policy_fee'
              policy_fee = rate['premium']
              next true
            end
            next false if rate['liability_only']
            next (rate['coverage_limits'].merge(rate['deductibles'])).all?{|name,sel| selections[name]&.[]('selection')&.[]('value') == sel } &&
                 (rate['schedule'] != 'optional' || 
                  (
                    (selections[rate['sub_schedule']]&.[]('selection') == true && (rate['individual_limit'] == 0 || rate['individual_limit'].nil?)) ||
                    (selections[rate['sub_schedule']]&.[]('selection')&.[]('value') == rate['individual_limit'])
                  )
                 )
          end
          policy_fee = 0 if policy_fee.nil?
          estimated_premium = selected_rates.inject(0){|sum,sr| sum + sr['premium'] }
          weight = billing_strategy.new_business['payments'].inject(0){|sum,w| sum + w }.to_d
          estimated_first_payment = (billing_strategy.carrier_code == 'FL' ? 0 : (billing_strategy.new_business['payments'][0] / weight * estimated_premium).floor)
          estimated_installment = (billing_strategy.carrier_code == 'FL' ? estimated_premium : (billing_strategy.new_business['payments'].drop(1).inject(0){|s,w| s + w } / (billing_strategy.new_business['payments'].count{|w| w > 0 } * weight) * estimated_premium).floor)
        else # invalid carrier policy type for estimate performance
          estimated_premium_error = {
            internal: "Invalid carrier for estimation; carrier policy type provided was ##{carrier_policy_type.id}",
            external: "Unable to obtain estimate for this policy type"
          }
          valid = false
      end # end carrier switch statement
    end # end if perform_estimate
    # add fields to selections, if requestsed
    if add_selection_fields
      selections = selections.map do |uid, sel|
        covopt = coverage_options[uid]
        next [uid,sel] unless covopt
        [
          uid,
          sel.merge(case carrier_policy_type.carrier_id
            when ::QbeService.carrier_id
              remove_overridability_data!({
                'title' => covopt['title'],
                'category' => covopt['category'],
                'options_type' => covopt['options_type']
              })
            when ::MsiService.carrier_id
              remove_overridability_data!({
                'title' => covopt['title'],
                'category' => covopt['category'],
                'options_type' => covopt['options_type']
              })
            else
              {}
          end)
        ]
      end.to_h
    end
    # done
    return {
      valid: valid,
      coverage_options: remove_overridability_data!(coverage_options.select{|k,v| v['visible'] && v['requirement'] != 'forbidden' }),
      estimated_premium: estimated_premium,
      estimated_installment: estimated_installment,
      estimated_first_payment: estimated_first_payment,
      policy_fee: policy_fee,
      errors: estimated_premium_error,
      annotated_selections: selections
    }.merge(eventable.class != ::PolicyQuote ? {} : {
      msi_data: result,
      event: event
    })
  end









  private
    
  
    # Class Methods
  
    def self.get_configurer_hierarchy(configurer, carrier, agency: nil) # if configurer is an account, agency lets you choose an agency to use (default is account.agency)
      to_return = [configurer]
      case configurer
        when ::Carrier
          # do nothing
        when ::Agency
          to_return.concat(configurer.agency_hierarchy(include_self: false) + [carrier])
        when ::Account
          to_return.concat((agency || configurer.agency).agency_hierarchy(include_self: true) + [carrier])
      end
      return(to_return.reverse)
    end
    
    
    def self.get_configurable_hierarchy(configurable, union_mode: false)
      to_return = []
      case configurable
        when ::Insurable, ::Address
          address = (configurable.class == ::Address ? configurable : configurable.primary_address)
          to_return = address.parent_insurable_geographical_categories.to_a.sort + (configurable.class == ::Insurable ? configurable.insurable_hierarchy : [])
        when ::InsurableGeographicalCategory
          to_return = configurable.query_for_parents
          to_return = to_return.or(configurable.query_for_children) if union_mode
          to_return = to_return.to_a.sort
      end
      return to_return
    end

    # traits_override is used to override the traits normally provided by the CarrierInsurableProfile, so that for nonpreferred we don't actually make a CIP with bogus default values
    # force_address_specific_rates is used to compel synchronous fetching of rates for our specific community, instead of using cached regional rates
    #   -- fasr is forced ON right now, because we aren't using regional rates... regional rates need to be updated to support the new "applicability" functionality
    def self.qbe_prepare_for_get_coverage_options(community, cip, number_insured, effective_date, traits_override: {}, force_address_specific_rates: false)
      force_address_specific_rates = true # MOOSE WARNING: see note above. need to update regional system before allowing this to work.
      effective_date = Time.current.to_date + 1.day if effective_date.nil?
      # build CIP if none exists
      unless cip
        community.create_carrier_profile(QbeService.carrier_id)
        cip = community.carrier_profile(QbeService.carrier_id)
      end
      # perform get zip code if needed
      unless cip.data["county_resolved"] || (community.get_qbe_zip_code && cip.reload.data["county_resolved"])
        return "insurable_rate_configuration.qbe.county_failure"
      end
      # perform get property info if needed
      unless cip.data["property_info_resolved"] || (community.get_qbe_property_info && cip.reload.data["property_info_resolved"])
        return "insurable_rate_configuration.qbe.property_info_failure"
      end
      # perform get rates if needed
      cpt = CarrierPolicyType.where(carrier_id: QbeService.carrier_id, policy_type_id: ::PolicyType::RESIDENTIAL_ID).take
      applicability = QbeService.get_applicability(community, traits_override, cip: cip)
      unless cip.data['rates_resolution']&.[](number_insured.to_s) &&
            ::InsurableRateConfiguration.where(
              configurer_type: "Carrier", configurer_id: ::QbeService.carrier_id, configurable: community, carrier_policy_type: cpt,
            ).find{|irc| irc.rates['applicability'] == applicability && irc.rates['rates']&.[](number_insured.to_i) }
        # begin 'unless' code here, sorry for the hideous indentation
        if cip.data['rates_resolution']&.[](number_insured.to_s)
          cip.data['rates_resolution'][number_insured.to_s] = false
          cip.save
        end
        # try strategies involving not getting the rates if we can
        do_synchronous_get = false
        if force_address_specific_rates
          do_synchronous_get = true
        else
          # we use the regional rate and run the address-specific rate fetch in the background--unless there is no regional rate, in which case we also do that synchronously
          igc = community.primary_address.parent_insurable_geographical_categories.to_a.sort.find{|cat| cat.special_usage == 'qbe_ho4' && !cat.insurable_id.nil? }
          if igc.nil?
            do_synchronous_get = true
          else
            irc = igc.insurable_rate_configurations.where(configurer_type: "Carrier", configurer_id: ::QbeService.carrier_id, configurable: igc, carrier_policy_type: cpt).take
            if irc.nil? || irc.rates&.[]('rates')&.[](number_insured.to_i).blank?
              # the regional IRC hasn't yet been filled with rates we can use; fall back to synchronous get
              do_synchronous_get = true
            else
              # the regional IRC has plenty of rates for us to use; there's nothing else we need to do
            end
          end
        end
        # actually get the rates
        if do_synchronous_get
          # we synchronously pull the rates we need
          diagnostics_hash = {}
          unless (community.get_qbe_rates(number_insured, effective_date, traits_override: traits_override, diagnostics_hash: diagnostics_hash) && cip.reload.data['rates_resolution']&.[](number_insured.to_s))
            # WARNING: diagnostics_hash[:event] will contain the event recording the getRates call (assuming such an event was successfully saved); we can use it to return custom failures for custom situations
            return "insurable_rate_configuration.qbe.rates_failure"
          end
        end
        # queue up detailed rate pulls to speed things up later, if any rates are missing
        community.fix_qbe_rates(false, traits_override: traits_override, delay: 0)
      end
      # all done
      return nil
    end
    
    # Data type tools
    
    def self.copy_with_deserialization(input)
      case input
        when ::Hash
          transformed = input.transform_values{|val| copy_with_deserialization(val) }
          transformed.has_key?('data_type') ? hash_deserialize(transformed) : transformed
        when ::Array
          input.map{|val| copy_with_deserialization(val) }
        else
          input
      end
    end
    
    def self.copy_with_serialization(input)
      case input
        when ::Hash
          transformed = input.transform_values{|val| copy_with_serialization(val) }
          transformed.has_key?('data_type') ? hash_serialize(transformed) : transformed
        when ::Array
          input.map{|val| copy_with_serialization(val) }
        else
          input
      end
    end
    
    def self.hash_serialize(var)
      case var['data_type']
        when 'currency'
          var
        when 'percentage'
          var.to_s
        else
          var
      end
    end
    
    def self.hash_deserialize(var)
      case var['data_type']
        when 'currency'
          Integer(var)
        when 'percentage'
          BigDecimal(var)
        else
          var
      end
    end
    
    # Validations
    
    def validate_configuration
      error_hash = {}
      result = self.class.validate_data_structure(self.configuration, carrier_policy_type.carrier_id == ::MsiService.carrier_id ? MSI_STRUCTURE : QBE_STRUCTURE, errors: error_hash)
      self.configuration = result
      self.apply_errors_from_hash(error_hash)
    end
    
end



