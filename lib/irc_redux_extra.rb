
class InsurableRateConfiguration < ApplicationRecord

  include Structurable
  include Scriptable

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
  
  before_save :refresh_max_overridability,
    if: Proc.new{|irc| irc.will_save_change_to_attribute?('configuration') } # MOOSE WARNING: should we apply copy_with_serialization?
  
  # Validations
  
  validate :validate_configuration
  
  # Structurable structures used in this model (and a helpful rule-to-text method)
  
  RULES_STRUCTURE => {
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
                  when 'compares_fixed'
                    break "has invalid comparator '#{params['comparator']}'" unless ['=','<','>','<=','>='].include?(params['comparator'])
                    break "has invalid object '#{params['object']}' (expected a valid decimal number or a currency or percentage data type hash)" unless (BigDecimal(params['object'], 3) rescue false) || (params['object'].class == ::Hash && ['currency', 'percentage'].include?(params['object']['data_type']) && (BigDecimal(params['object']['value'], 3) rescue false))
                  when 'compares_coverage'
                    break "has invalid comparator '#{params['comparator']}'" if !['=','<','>','<=','>='].include?(params['comparator'])
                    break "has invalid object '#{params['object']}' (expected a string representing a coverage UID)" unless params['object'].class == ::String
                  when 'compares_percent'
                    break "has invalid comparator '#{params['comparator']}'" if !['=','<','>','<=','>='].include?(params['comparator'])
                    break "has invalid percent '#{params['percent']}' (expected a valid decimal number)" unless (BigDecimal(params['percent'], 3)
                    break "has invalid object '#{params['object']}' (expected a string representing a coverage UID)" unless params['object'].class == ::String
                  when 'greatest_of_fixed_or_percent'
                    break "has invalid fixed '#{params['fixed']}' (expected a valid decimal number or a currency or percentage data type hash)" unless (BigDecimal(params['fixed'], 3) rescue false) || (params['fixed'].class == ::Hash && ['currency', 'percentage'].include?(params['fixed']['data_type']) && (BigDecimal(params['fixed']['value'], 3) rescue false))
                    break "has invalid percent '#{params['percent']}' (expected a valid decimal number)" unless (BigDecimal(params['percent'], 3)
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
            "#{coverage_options[params]&.[]('title') || "Coverage Option #{params}"} is selected"
          when 'coverage_not_selected'
            "#{coverage_options[params]&.[]('title') || "Coverage Option #{params}"} is not selected"
          else
            throw 'fail'
        end
      end.compact.join(" and ") + " then "
      # get subject
      subject = coverage_options[rule['subject']]
      subject_title = subject&.[]('title') || "Coverage Option #{rule['subject']}"
      # add in rule body
      to_return += rule['rule'].map do |rule_type, params|
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
            'validity' = ['currency', 'percentage'],
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
  }

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
          'external_id' => {
            'required' => true,
            'validity' => Proc.new{|v| v.class == ::String },
            'default_overridability' => 0
          },
          'description' => {
            'required' => false,
            'validity' => Proc.new{|v| v.nil? || v.class == ::String },
            'default_overridability' => Proc.new{|v,uid,data,irc| v.nil? ? nil : 0 }
          }
        }.merge(CRITICAL_SUBSTRUCTURE) # end coverage_options/special_data/structure
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
  def self.get_inherited_irc(carrier_policy_type, configurer, configurable, agency: nil)
    # Alternative: merge(get_hierarchy(carrier_policy_type, configurer, configurable, agency: agency).map{|ircs| merge(ircs, true) }, false)
    hierarchy = get_hierarchy(carrier_policy_type, configurer, configurable, agency: agency)
    merge(hierarchy.flatten, hierarchy.map.with_index{|ircs, index| ircs.map{|irc| index } }.flatten)
  end
  
  
  # Merge an array of IRCs together.
  # params:
  #   irc_array:          an array of IRCs
  #   override_level:     true to treat IRCs as having the same override level, false to treat them as having override levels equal to their indices, array of integers to provide explicit offsets
  # returns:
  #   an IRC representing the combination of all the IRCs in the array
  def self.merge(irc_array, override_level)
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
        v1 == v2 ? v1 : (v1.nil? ^ v2.nil?) ? (v1 || v2) : condemnation
      end
    end
    # configuration
    offsets = override_level.class == ::Array ? override_level : override_level ? 0 : [0...-1].map{|irc| irc.max_overridability }.inject([0]){|arr,mo| arr.concat(arr.last + mo + 1) }
    to_return.configuration = merge_data_structures(irc_array.map{|irc| irc.configuration }, CONFIGURATION_STRUCTURE, offsets)
    to_return.refresh_max_overridability
    # done
    return to_return
  end
  
  
  # Get the IRC inheritance hierarchy for a given configuration.
  # params:
  #   carrier_policy_type:    the CPT for which to pull IRCs
  #   configurer:             an account/agency/carrier
  #   configurable:           an InsurableGeographicalCategory or an insurable's CarrierInsurableProfile
  #   agency:                 (optional) if configurer is an account, you can provide an agency to use instead of configurer.agency if desired
  # returns:
  #   an array (ordered from least to most specific configurer) of arrays (ordered from least to most specific configurable) of IRCs
  def self.get_hierarchy(carrier_policy_type, configurer, configurable, agency: nil)
    # get configurer and configurable hierarchies
    configurers = get_configurer_hierarchy(configurer, carrier_policy_type.carrier, agency: agency)
    configurables = get_configurable_hierarchy(configurable)
    # get the insurable rate configurations
    to_return = ::InsurableRateConfiguration.where(configurer: configurers, configurable: configurables, carrier_policy_type: carrier_policy_type)
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
    return coverage_options
=begin
  # NEEDS TO BE MODIFIED FOR NEW RULES
  
  
equal to greater of FIXED or PERCENT of COV[, unless COV2 (then greater of FIXED or PERCENT)]
  # do as two rules with mutex conditions
equal to PERCENT of COV
  {
    'subject' => 1099, # some uid
    'rule' => { 'eq_percent' => { 'coverage' => 1095, 'percent' => 20.5 } },
    'condition' => { 'coverage_selected' => 1095 }
  }
leq FIXED
  {
    'subject' => 1099, # some uid
    'rule' => { 'leq_fixed' => { 'data_type' => 'currency', 'value' => 1000 } },
    'condition' => { 'selected_coverage' => 1095 }
  }
leq COV
  {
    'subject' => 1099, # some uid
    'rule' => { 'leq_coverage' => 1095 },
    'condition' => true
  }
greater than FIXED when COV selected
  {
    'subject' => 1099, # some uid
    'rule' => { 'eq_fixed' => { 'data_type' => 'currency', 'value' => 1000 } },
    'condition' => { 'coverage_selected' => 1095 }
  }
equal to FIXED
  {
    'subject' => 1099, # some uid
    'rule' => { 'eq_fixed' => { 'data_type' => 'currency', 'value' => 1000 } },
    'condition' => true
  }

  
  
  
  
  
  
  
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
=end
  end
  
  # insert_invisible_requirements will insert visible == false, requirement == 'required' options into the selections hash;
  # it is assumed that these will all have 'options_type' == 'none'; if some are 'multiple_choice', pass insert_invisible_requirements a hash mapping their UIDs to the desired selections. Otherwise, it will pick the first option automatically
  def get_selection_errors(selections, options = annotate_options(selections), use_titles: false, insert_invisible_requirements: true)
    to_return = {}
    options.select{|uid,opt| opt['requirement'] == 'required' }.each do |opt|
      if !selections[uid]
        if opt['visible'] == false && insert_invisible_requirements
          selections[uid] = case opt['options_type']
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
    selections.select{|uid,sel| sel }.each do |sel|
      #next if options[uid].nil? # WARNING: for now we just ignore selections that aren't in the options... NOPE, RESTORED ERROR. But left this here because I don't remember why it was here to begin with
      if options[uid].nil? || options[uid]['requirement'] == 'forbidden'
        (to_return[uid] ||= []).push("is not a valid coverage option")
      elsif sel == true
        (to_return[uid] ||= []).push("selection cannot be blank") if options[uid]['options_type'] != 'none'
      else
        found = (options[uid]['options'] || {}).find{|opt| opt['data_type'] == sel['data_type'] && opt['value'] == sel['value'] }
        (to_return[uid] ||= []).push("has invalid selection '#{sel['value']}'") if found.nil?
      end
    end
    if use_titles
      to_return.transform_keys!{|uid| options[uid]&.[]('title') || 'Coverage Option #{uid}' }
    end
    return to_return
  end
  
  def self.automatically_select_options(options, selections = {}, iterations: 1, rechoose_selection: Proc.new{|option,selection| option['requirement'] == 'required' ? (option['options_type'] == 'multiple_choice' ? option['options'].min{|a,b| a['value'].to_d <=> b['value'].to_d } : true) : nil })
    options.map do |uid, opt|
      sel = selections[uid]
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
    end.compact.to_h.compact
  end


  def self.get_coverage_options(carrier_policy_type, insurable, selections, effective_date, additional_insured_count, billing_strategy_carrier_code,    # required data
                                eventable: nil, perform_estimate: true, estimate_default_on_billing_strategy_code_failure: :min,                        # execution options
                                additional_interest_count: nil, agency: nil, account: insurable.class == ::Insurable ? insurable.account : nil,         # optional/overridable data
                                nonpreferred_final_premium_params: {})                                                                                  # special optional data
    # clean up insurable info
    unit = nil
    if insurable.class == ::Insurable && !::InsurableType::COMMUNITIES_IDS.include?(insurable.insurable_type_id)
      unit = insurable
      insurable = insurable.parent_community
    end
    cip = (insurable.class != ::Insurable ? nil : insurable.carrier_profile(carrier_policy_type.carrier_id))
    # get coverage options and selection errors
    selections = selections.select{|uid, sel| sel }
    irc = get_inherited_irc(carrier_policy_type, account || agency || carrier_policy_type.carrier, insurable, agency: agency)
    coverage_options = irc.annotate_options(selections).select!{|co| co['enabled'] != false }
    selection_errors = irc.get_selection_errors(selections, coverage_options, insert_invisible_requirements: true)
    valid = selection_errors.blank?
    estimated_premium_error = valid ? nil : { internal: selection_errors, external: selection_errors }
    if perform_estimate
      case carrier_policy_type.carrier_id
        when ::MsiService.carrier_id
          # fix up selections and get preferred status
          selections = automatically_select_options(coverage_options, selections) unless valid
          preferred = cip && !cip.external_carrier_id.blank? && (unit.nil? || unit.account_id == insurable.account_id)
          # prepare the call
          msis = MsiService.new
          result = msis.build_request(:final_premium,
            effective_date: effective_date, 
            additional_insured_count: additional_insured_count,
            additional_interest_count: additional_interest_count || (insurable.class == ::Insurable && (!insurable.account_id.nil? || !insurable.parent_community&.account_id.nil?) ? 1 : 0),
            coverages_formatted:  selections.map do |uid, sel|
                                    next nil unless sel
                                    covopt = coverage_options[uid]
                                    next nil unless covopt
                                    next { CoverageCd: uid }.merge(sel == true ? {} : {
                                      (covopt['category'] == 'deductible' ? :Deductible : :Limit) => { Amt: BigDecimal(sel['value']) / 100.to_d } # same whether sel['data_type'] is 'percentage' or 'currency', since currency stores number of cents
                                    })
                                  end.compact,
            **(preferred ?
                { community_id: cip.external_carrier_id }
                : { address: insurable.primary_address }.merge(nonpreferred_final_premium_params.compact)
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
        
        
          ####### MOOSE WARNING: PUT RATE CALCULATIONS HERE #########
        
        
        
        
        else # invalid carrier policy type for estimate performance
          estimated_premium_error = {
            internal: "Invalid carrier for estimation; carrier policy type provided was ##{carrier_policy_type.id}",
            external: "Unable to obtain estimate for this policy type"
          }
          valid = false
      end # end carrier switch statement
    end # end if perform_estimate
    # done
    return {
      valid: valid,
      coverage_options: coverage_options.select{|k,v| v['visible'] },
      estimated_premium: estimated_premium,
      estimated_installment: estimated_installment,
      estimated_first_payment: estimated_first_payment,
      installment_fee: installment_fee,
      errors: estimated_premium_error,
    }.merge(eventable.class != ::PolicyQuote ? {} : {
      msi_data: result,
      event: event,
      annotated_selections: selections
    })
  end




  private
    
  
    # Class Methods
  
    def self.get_configurer_hierarchy(configurer, carrier, agency: nil) # if configurer is an account, agency lets you choose an agency to use (default is account.agency)
      to_return = [configurer]
      case configurer.class
        when ::Carrier
          # do nothing
        when ::Agency
          to_return.concat(configurer.agency_hierarchy(include_self: false) + [carrier])
        when ::Account
          to_return.concat((agency || configurer.agency).agency_hierarchy(include_self: true) + [carrier])
      end
      return(to_return)
    end
    
    
    def self.get_configurable_hierarchy(configurable)
      to_return = []
      case configurable.class
        when ::Insurable
          address = configurable.primary_address
          to_return = [configurable] + ::InsurableGeographicalCategory.where(state: nil)
            .or(::InsurableGeographicalCategory.where(state: address.state, counties: nil))
            .or(::InsurableGeographicalCategory.where(state: address.state).where('counties @> ARRAY[?]::varchar[]', address.county)
            .to_a.sort
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



