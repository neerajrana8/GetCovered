class InsurableRateConfiguration < ApplicationRecord

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
  
  # Validations
  
  #validate :validate_coverage_options MOOSE WARNING: restore this after modifying it to allow missing keys (because of inheritance)
  validate :validate_rules
  
  # Useful constants
  
  # Available values for 'requirement', associated with numerical distinguishing values.
  REQUIREMENT_TYPES = {
    'required' => 0,    # coverage must be selected
    'forbidden' => 1,   # coverage may not be selected
    'optional' => 2,    # coverage can be selected if desired
    'locked' => 3       # coverage may not be selected by default, but rules, even from lower configurers, can override this
  }
  
  # Requirement types which can be overwritten by lower configurers
  OVERWRITEABLE_REQUIREMENT_TYPES = ['optional', 'locked']
  
  # Configurer types for sorting
  CONFIGURER_SORTING_ORDER = {
    'Carrier' => 0,
    'Agency' => 1,
    'Account' => 2
  }
  
  # Configurer types which can add distinct new coverages
  COVERAGE_ADDING_CONFIGURERS = {
    'Carrier' => true
  }
  
  # Public Methods
  
  def self.get_hierarchy(carrier_insurable_type, configurer, configurable)
    # grab classes and ids, build query
    configurer_type = configurer.class.name
    configurer_id = configurer.id
    configurable_type = configurable.class.name
    configurable_id = configurable.id
    carrier_insurable_type_id = carrier_insurable_type.id
    query = ::InsurableRateConfiguration.joins(:insurable_geographical_category).includes(:insurable_geographical_category).references(:insurable_geographical_categories).where(carrier_insurable_type_id: carrier_insurable_type_id)
    # add configurer restrictions to query
    query = add_configurer_restrictions(query, configurer, carrier_insurable_type.carrier_id)
    # add configurable restrictions to query
    to_add = []
    case configurable_type
      when 'CarrierInsurableProfile'
        address = configurable.insurable.primary_address
        return [] if address.nil?
        query = query.where(insurable_geographical_categories: { state: nil })
                     .or(query.where(insurable_geographical_categories: { state: address.state, counties: nil }))
                     .or(query.where(insurable_geographical_categories: { state: address.state }).where('insurable_geographical_categories.counties @> ARRAY[?]::varchar[]', address.county))
        to_add = add_configurer_restrictions(::InsurableRateConfiguration.where(carrier_insurable_type_id: carrier_insurable_type_id), configurer, carrier_insurable_type.carrier_id)
                 .where(configurable_type: 'CarrierInsurableProfile', configurable_id: configurable_id)
      when 'InsurableGeographicalCategory'
        if configurable.state.nil?
          query = query.where(insurable_geographical_categories: { state: nil })
        elsif configurable.counties.blank?
          query = query.where(insurable_geographical_categories: { state: nil })
                       .or(query.where(insurable_geographical_categories: { state: configurable.state, counties: nil }))
        else
          query = query.where(insurable_geographical_categories: { state: nil })
                       .or(query.where(insurable_geographical_categories: { state: configurable.state, counties: nil }))
                       .or(query.where(insurable_geographical_categories: { state: configurable.state }).where('insurable_geographical_categories.counties @> ARRAY[?]::varchar[]', configurable.counties))
        end
      else
        return []
    end
    # sort into hierarchy
    to_return = query.to_a.group_by{|irc| irc.configurer_type }
    to_return = to_return.values
    to_return.sort_by!{|ircs| (CONFIGURER_SORTING_ORDER[ircs.first.configurer_type] || 999999) }
    to_return.each{|ircs| ircs.sort_by!(&:insurable_geographical_category) }
    # add in add-in (they'll always go at the end)
    to_add.each do |irc|
      found = to_return.find{|ircs| ircs.first.configurer_type == irc.configurer_type }
      if found
        found.push(irc)
      else
        to_return.push([irc])
      end
    end
    # done
    return to_return
  end
  
  def get_parent_hierarchy(include_self: false)
    query = ::InsurableRateConfiguration.joins(:insurable_geographical_category).includes(:insurable_geographical_category).where(carrier_insurable_type_id: carrier_insurable_type_id)
    # add configurer restrictions to query
    query = self.class.add_configurer_restrictions(query, configurer, carrier_insurable_type.carrier_id)
    # add configurable restrictions to query
    case configurable_type
      when 'CarrierInsurableProfile'
        address = configurable.insurable.primary_address
        return [] if address.nil?
        query = query.where(insurable_geographical_categories: { state: nil })
                     .or(query.where(insurable_geographical_categories: { state: address.state, counties: nil }))
                     .or(query.where(insurable_geographical_categories: { state: address.state }).where('insurable_geographical_categories.counties @> ARRAY[?]::varchar[]', address.county))
      when 'InsurableGeographicalCategory'
        if configurable.state.nil?
          query = query.where(insurable_geographical_categories: { state: nil })
        elsif configurable.counties.blank?
          query = query.where(insurable_geographical_categories: { state: nil })
                       .or(query.where(insurable_geographical_categories: { state: configurable.state, counties: nil }))
        else
          query = query.where(insurable_geographical_categories: { state: nil })
                       .or(query.where(insurable_geographical_categories: { state: configurable.state, counties: nil }))
                       .or(query.where(insurable_geographical_categories: { state: configurable.state }).where('insurable_geographical_categories.counties @> ARRAY[?]::varchar[]', configurable.counties))
        end
      else
        return []
    end
    # remove ourselves
    query = query.where.not(id: self.id) unless self.id.nil?
    # sort into hierarchy
    to_return = query.to_a.group_by{|irc| irc.configurable_type }.values
    to_return.sort_by!{|ircs| (CONFIGURER_SORTING_ORDER[ircs.first.configurer_type] || 999999) }
    to_return.each{|ircs| ircs.sort_by!(&:configurable) }
    # shove ourselves in
    if include_self
      index = to_return.index{|ircs| ircs.first.configurer_type == self.configurer_type }
      if index.nil?
        to_return.push([self])
      else
        to_return[index].push(self)
      end
    end
    # done
    return to_return
  end
  
  def self.merge(irc_array, mutable:)
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
    #irc_array.each do |irc|
    #  irc.carrier_info.each do |k,v|
    #    mv = Marshal.dump(v)
    #    if to_return.carrier_info.has_key?(k)
    #      to_return.carrier_info[k] = nil unless to_return.carrier_info[k] == mv
    #    else
    #      to_return.carrier_info[k] = v
    #    end
    #  end
    #end
    #to_return.carrier_info.compact!
    #to_return.carrier_info.transform_values!{|v| Marshal.load(v) }
    # rules
    if mutable
      irc_array.each{|irc| to_return.rules.merge!(irc.rules) }
    else
      # WARNING: only messages are overwritten; code is IGNORED when the rule already exists. alternative is to include code as a separate rule (change the name)
      irc_array.each do |irc|
        irc.rules.each do |r_name, r_data|
          if to_return.rules.has_key?(r_name)
            to_return.rules[r_name]['message'] = r_data['message']
          else
            to_return.rules[r_name] = Marshal.load(Marshal.dump(r_data))
          end
        end
      end
    end
    # coverage_options
    to_return.coverage_options = irc_array.first&.coverage_options || []
    irc_array.drop(1).each do |irc|
      to_return.merge_options!(irc.coverage_options, mutable: mutable, allow_new_coverages: irc.configurer_type.nil? ? mutable : COVERAGE_ADDING_CONFIGURERS.include?(irc.configurer_type))
    end
    # done
    return to_return
  end
  
  # merge parent options into self.coverage_options (does not save the model)
  def merge_options!(parent_options, mutable:, allow_new_coverages: mutable)
    self.coverage_options = merge_options(parent_options, mutable: :mutable, allow_new_coverages: allow_new_coverages)
    return self
  end
  
  # merges parent options into child options
  def merge_options(
    parent_options,
    child_options = self.coverage_options,
    mutable:,
    allow_new_coverages: mutable
  )
    to_return = Marshal.load(Marshal.dump(parent_options))
    child_options.each do |co|
      # grab the corresponding parent option
      po = to_return.find{|opt| opt['category'] == co['category'] && opt['uid'] == co['uid'] }
      if po.nil?
        # ignore or insert the new coverage option
        next if !allow_new_coverages
        to_return.push(co)
      else
        # see about overrides
        po['title'] = co['title'] unless co['title'].nil?
        po['description'] = co['description'] unless co['description'].nil?
        po['enabled'] = co['enabled'] unless co['enabled'].nil? || (!mutable && po['enabled'] == false)
        po['requirement'] = co['requirement'] unless co['requirement'].nil? || (!mutable && !OVERWRITEABLE_REQUIREMENT_TYPES.include?(po['requirement']))
        if mutable
          po['options_type'] = co['options_type'] unless co['options_type'].nil?
          po['options'] = co['options'] unless co['options'].nil?
        elsif co['options_type'] && co['options']
          refine_options_for_merge!(po['options_type'], po['options'], co['options_type'], co['options'])
        end
      end
    end
    return to_return
  end
  
  # refine parent (po) options by filtering out options not compatible with child (co) options;
  # uses coverage_options format
  def refine_options_for_merge!(po_type, po_options, co_type, co_options)
    refine_options_for_code!(po_type, po_options, asserts_for_options(co_type, co_options))
  end
  
  # converge coverage_options options format to asserts format
  def asserts_for_options(options_type, options)
    case options_type
      when 'multiple_choice'
        return([options])
    end
    return []
  end
  
  def validate_coverage_options
    # Coverage schema:
    #{
    #  "category"      => 'coverage' or 'deductible',
    #  "uid"           => string,
    #  "title"         => string,
    #  "description"   => string (optional)",
    #  "enabled"       => boolean,
    #  "requirement"   => string (from among REQUIREMENT_TYPES),
    #  "options_type"  => ["none", "multiple_choice"],
    #  "options_format"=> 'none' if options_type is 'none, otherwise 'currency' or 'percent',
    #  "options"       => depends on options_type:
    #     none: omit this entry, it doesn't matter,
    #     multiple_choice: array of numerical values
    #}
    self.coverage_options.each.with_index do |cov,i|
      disp_title = cov["title"].blank? ? "coverage option ##{i}" : cov["title"]
      errors.add(:coverage_title, "cannot be blank (#{disp_title})") if cov["title"].blank?
      errors.add(:coverage_uid, "cannot be blank (#{disp_title})") if cov["uid"].blank?
      # description can be blank
      errors.add(:coverage_requirement, "must be 'required', 'disabled', 'optional', or 'locked' (#{disp_title})") unless REQUIREMENT_TYPES.has_key?(cov["requirement"])
      errors.add(:coverage_requirement_enabled, "must be true or false (#{disp_title}") unless [true, false].include?(cov["requirement_enabled"])
      errors.add(:coverage_category, "must be 'coverage', or 'deductible'") unless ['coverage', 'deductible'].include?(cov["category"])
      case cov["options_type"]
        when "none"
          # all good
        when "multiple_choice"
          errors.add(:coverage_options, "must be a set of numerical options (#{disp_title})") unless cov["options"].class == ::Array # MOOSE WARNING: check numericality
        else
          errors.add(:coverage_options_type, "must be 'none' or 'multiple_choice' (#{disp_title})")
      end
    end
  end
  
  def validate_rules
    self.rules.each do |r_name, r_data|
      unless r_data.class == ::Hash
        errors.add(:rules, "includes invalid rule (#{r_name})")
      else
        errors.add(:rules, "includes rule without message (#{r_name})") unless r_data.has_key?("message")
        errors.add(:rules, "includes rule without specification (#{r_name})") unless r_data.has_key?("code")
        # MOOSE WARNING: add errors for invalid rule code syntax (but right now only there's no rule customization, just valid seeds); code can be nil, or valid syntax
      end
    end
  end
  
  # options should be a copy of self.coverage_options, or the same with parents merged in
  # selections should be an array of hashes of the form { 'category'=>cat, 'uid'=>uid, 'selection'=>sel }, where sel is the # selected if applicable, and otherwise true or false
  def annotate_options(selections, options = self.coverage_options, skip_copy: false)
    # copy options
    options = Marshal.load(Marshal.dump(options)) unless skip_copy
    # apply rules to get asserts
    asserts = []
    self.rules.map{|k,v| v['code'] }.compact.each do |code|
      execute(code, options, selections, asserts: asserts)
    end
    # apply asserts
    asserts.each do |assert|
      option = options.find{|opt| opt['category'] == assert['category'] && opt['uid'] == assert['uid'] }
      next if option.nil?
      if assert['requirement']
        unless option['requirement_locked'] # MOOSE WARNING: make sure this is implemented in merge
          # if there are multiple asserts, let non-optional statuses override optional statuses and take the last one
          option['requirement'] = REQUIREMENT_TYPES.key(assert['requirement'].select{|v| v != REQUIREMENT_TYPES['optional'] }.last || REQUIREMENT_TYPES['optional'])
        end
      end
      if assert['value']
        refine_options_for_code!(option['options_type'], option['options'], assert['value'])
      end
    end
    # done
    return options
  end
  
  def refine_options_for_code!(options_type, options, asserts)
    case options_type
      when 'multiple_choice'
        asserts.each do |assert|
          if assert.class == ::Array
            options.select!{|opt| assert.include?(opt) }
          elsif assert.class == ::Hash
            case assert['interval']
              when '()'
                options.select!{|opt| opt > assert['start'] && opt < assert['end'] }
              when '(]'
                options.select!{|opt| opt > assert['start'] && opt <= assert['end'] }
              when '[)'
                options.select!{|opt| opt >= assert['start'] && opt < assert['end'] }
              when '[]'
                options.select!{|opt| opt >= assert['start'] && opt <= assert['end'] }
            end
          else
            options.select!{|opt| opt.to_d == assert }
          end
        end
    end
  end
  
  # params:
  #   selections: an array of hashes of the form { 'category'=>cat, 'uid'=>uid, 'selection'=>sel }, where sel is the # selected if applicable, and otherwise true or false
  #   asserts: internal use, keeps track of where in the syntax asserts are allowed (false if not allowed, array of asserts if allowed)
  # returns:
  #   value of executed expression
  def execute(code, options, selections, asserts: false)
    case code
      when ::Array
        case code[0]
          when '='
            if !asserts
              return false # throws disabled for now: throw 'invalid_assert_placement'
            else
              if code[1].class == ::Array
                if code[1][0] == 'requirement'
                  # get what to assign and what to assign it to
                  category = execute(code[1][1], options, selections).to_s
                  uid = execute(code[1][2], options, selections).to_s
                  value = execute(code[2], options, selections)
                  # perform the assignation
                  index = asserts.find_index{|a| a['category'] == category && a['uid'] == uid }
                  if index.nil?
                    index = asserts.length
                    asserts[index] = { 'category' => category, 'uid' => uid }
                  end
                  asserts[index]['requirement'] = [] if asserts[index]['requirement'].nil?
                  asserts[index]['requirement'].push(value)
                  asserts[index]['requirement'].uniq!
                  true
                elsif code[1][0] == 'value'
                  # get what to assign and what to assign it to
                  category = execute(code[1][1], options, selections).to_s
                  uid = execute(code[1][2], options, selections).to_s
                  value = execute(code[2], options, selections)
                  # perform the assignation
                  index = asserts.find_index{|a| a['category'] == category && a['uid'] == uid }
                  if index.nil?
                    index = asserts.length
                    asserts[index] = { 'category' => category, 'uid' => uid }
                  end
                  asserts[index]['value'] = [] if asserts[index]['value'].nil?
                  asserts[index]['value'].push(value)
                  asserts[index]['value'].uniq! # WARNING: might be array of values or an interval (see '[], '()', etc. case below)
                  true
                else
                  return false # throws disabled for now: throw 'invalid_assert_subject_code'
                end
              else
                return false # throws disabled for now: throw 'invalid_assert_subject_value'
              end
            end
          when '?', 'if'
            execute(code[1], options, selections) ? execute(code[2], options, selections, asserts: asserts) : execute(code[3], options, selections, asserts: asserts)
          when ';'
            (1...code.length).each{|c| execute(c, options, selections, asserts: asserts); }
            true
          when '&&'
            (1...code.length).inject(true){|s,i| break false unless execute(code[i], options, selections, asserts: asserts); true }
          when '||'
            (1...code.length).inject(false){|s,i| break true if execute(code[i], options, selections, asserts: asserts); false }
          when '|'
            (1...code.length).inject([]){|s,i| temp = execute(code[i], options, selections); s += (temp.class == ::Array ? temp : [temp]) }
          when '[]', '()', '[)', '(]'
            { 'interval' => code[0], 'start' => num(execute(code[1], options, selections)), 'end' => num(execute(code[2], options, selections)) }
          when '=='
            (num(execute(code[1], options, selections)) - num(execute(code[2], options, selections))).abs <= (num(code[3], options, selections) || 0)
          when '<'
            (num(execute(code[1], options, selections)) - num(execute(code[2], options, selections))) < (num(code[3], options, selections) || 0)
          when '>'
            (num(execute(code[1], options, selections)) - num(execute(code[2], options, selections))) > -(num(code[3], options, selections) || 0)
          when '<='
            (num(execute(code[1], options, selections)) - num(execute(code[2], options, selections))) <= (num(code[3], options, selections) || 0)
          when '>='
            (num(execute(code[1], options, selections)) - num(execute(code[2], options, selections))) >= -(num(code[3], options, selections) || 0)
          when 'selected'
            selections.find{|s| s['category'] == execute(code[1], options, selections) && s['uid'] == execute(code[2], options, selections) }&.[]('selection') ? true : false
          when 'requirement'
            found = options.find{|s| s['category'] == execute(code[1], options, selections) && s['uid'] == execute(code[2], options, selections) }
            if found.nil? || found['enabled'] == false
              REQUIREMENT_TYPES['forbidden']
            else
              REQUIREMENT_TYPES[found['requirement'] || 'forbidden']
            end
          when 'value'
            found = selections.find{|s| s['category'] == execute(code[1], options, selections) && s['uid'] == execute(code[2], options, selections) }
            if found.nil? || found['selection'].nil?
              0.to_d # just return zero instead of throwing throw 'no_value'
            else
              found['selection']
            end
          when 'max'
            code.drop(1).map{|c| num(execute(c, options, selections)) }.max
          when 'min'
            code.drop(1).map{|c| num(execute(c, options, selections)) }.min
          when '+'
            num(execute(code[1], options, selections)) + num(execute(code[2], options, selections))
          when '-'
            num(execute(code[1], options, selections)) - num(execute(code[2], options, selections))
          when '*'
            num(execute(code[1], options, selections)) * num(execute(code[2], options, selections))
        end
      else
        code
    end
  end
  
  def num(val, crashable: false)
    case val
      when ::TrueClass
        throw 'invalid_number' if crashable
        1.to_d
      when ::FalseClass
        throw 'invalid_number' if crashable
        0.to_d
      when ::NilClass
        throw 'invalid_number' if crashable
        -BigDecimal::INFINITY
      when ::String
        case val
          when *(REQUIREMENT_TYPES.keys)
            REQUIREMENT_TYPES[val]
          else
            val.to_d
        end
      else # MOOSE WARNING: are there other possibilities besides numeric?
        val.to_d
    end
  end
  
  def can_define_coverages?
    configurer_type == 'Carrier'
  end
  
  def self.automatically_select_options(options, selections = [])
    options.map do |opt|
      next nil if opt['requirement'] != 'required' && opt['requirement'] != 'forbidden'
      sel = selections.find{|x| x['category'] == opt['category'] && x['uid'] == opt['uid'] }
      if opt['requirement'] == 'required'
        {
          'category' => opt['category'],
          'uid'      => opt['uid'],
          'selection'=> opt['options_type'] == 'none' || opt['options'].blank? ? true : !sel.nil? && opt['options'].map{|o| o.to_d }.include?(sel['selection'].to_d) ? sel['selection'] : opt['options'][rand(opt['options'].length)]
        }
      elsif opt['requirement'] == 'optional'
        next nil # WARNING: no optional coverages for now... randomize it later
      else
        next nil
      end
    end.compact
  end
  
  def self.get_coverage_options(carrier_id, carrier_insurable_profile, selections, effective_date, additional_insured_count, insurable_type_id: 4, account: carrier_insurable_profile.insurable.account, eventable: nil)
    cip = carrier_insurable_profile
    carrier_insurable_type = CarrierInsurableType.where(carrier_id: carrier_id, insurable_type_id: insurable_type_id).take
    # get IRCs
    irc_hierarchy = ::InsurableRateConfiguration.get_hierarchy(carrier_insurable_type, account, cip)
    irc_hierarchy.map!{|ircs| InsurableRateConfiguration.merge(ircs, mutable: true) }
    # for each IRC, apply rules and merge down
    coverage_options = []
    irc_hierarchy.each do |irc|
      irc.merge_options!(coverage_options, mutable: false, allow_new_coverages: COVERAGE_ADDING_CONFIGURERS.include?(irc.configurer_type))
      coverage_options = irc.annotate_options(selections)
    end
    # call GetFinalPremium to get estimate
    valid = false
    estimated_premium = {}
    estimated_premium_error = nil
    # MOOSE WARNING: add validation method for rule satisfaction, skip msi call if it fails
    msis = MsiService.new
    event = ::Event.new(
      eventable: eventable,
      verb: 'post',
      format: 'xml',
      interface: 'REST',
      endpoint: msi_service.endpoint_for(:final_premium),
      process: 'msi_final_premium'
    )
    result = msis.build_request(:final_premium,
      effective_date: effective_date, 
      additional_insured_count: additional_insured_count,
      additional_interest_count: 0, # MOOSE WARNING: or 1, to include prop manager?
      community_id: cip.external_carrier_id,
      coverages_formatted:  temp = selections.select{|s| s['selection'] }
                              .map{|s| s['options'] = coverage_options.find{|co| co['category'] == s['category'] && co['uid'] == s['uid'] }; s }
                              .select{|s| !s['options'].nil? }
                              .map do |sel|
                                if sel['category'] == 'coverage'
                                  {
                                    CoverageCd: sel['uid']
                                  }.merge(sel['selection'] == true ? {} : {
                                    Limit: { Amt: sel['selection'] }
                                  })
                                elsif sel['category'] == 'deductible'
                                  {
                                    CoverageCd: sel['uid']
                                  }.merge(sel['selection'] == true ? {} : {
                                    Deductible: sel['options']['options_format'] == 'percent' ? { FormatPct: sel['selection'].to_d / 100 } : { Amt: sel['selection'] }
                                  })
                                else
                                  nil
                                end
                              end.compact,
      line_breaks: true
    )
    if !result
      # failed to get final premium
      estimated_premium_error = { internal: msis.errors.to_s, external: "Unknown error occurred" }
    else
      # make the call
      event.request = msi_service.comkpiled_rxml
      event.save
      event.started = Time.now
      result = msis.call
      event.completed = Time.now
      event.response = msi_data[:data]
      event.status = msi_data[:error] ? 'error' : 'success'
      event.save
      # handle the result
      if result[:error]
        estimated_premium_error = { internal: result[:external_message].to_s, external: "Error calculating premium" } # MOOSE WARNING: probably just means selections aren't valid yet... check first maybe? should we set the error to result[:error] to send to the user?
      else
        valid = true
        estimated_premium = [result[:data].dig("MSIACORD", "InsuranceSvcRs", "RenterPolicyQuoteInqRs", "PersPolicy", "PaymentPlan")].flatten
                                        .map do |plan|
                                          [
                                            plan["PaymentPlanCd"],
                                            plan["MSI_TotalPremiumAmt"]["Amt"]
                                          ]
                                        end.to_h
      end
    end
    # done
    return {
      valid: valid,
      coverage_options: coverage_options,
      estimated_premium: estimated_premium,
      errors: estimated_premium_error
    }.merge(eventable.class != ::PolicyQuote ? {} : {
      msi_data: result,
      event: event
    })
  end
  
  private
  
    def self.add_configurer_restrictions(query, configurer, carrier_id)
      case configurer.class.name
        when 'Account'
          query.where(configurer_type: 'Account', configurer_id: configurer.id)
               .or(query.where(configurer_type: 'Agency', configurer_id: configurer.agency_id))
               .or(query.where(configurer_type: 'Carrier', configurer_id: carrier_id))
        when 'Agency'
          query.where(configurer_type: 'Agency', configurer_id: configurer.id)
               .or(query.where(configurer_type: 'Carrier', configurer_id: carrier_id))
        when 'Carrier'
          query.where(configurer_type: 'Carrier', configurer_id: configurer.id)
        else
          return []
      end
    end
end
