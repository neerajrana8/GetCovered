class InsurableRateConfiguration < ApplicationRecord
  belongs_to :configurable, polymorphic: true # Insurable or InsurableGeographicCategory (for now)
  belongs_to :configurer, polymorphic: true   # Account, Agency, or Carrier
  belongs_to :carrier_insurable_type
  
  validate :validate_coverage_options
  
  REQUIREMENT_TYPES = {
    'required' => 0,
    'forbidden' => 1,
    'optional' => 2,
    'locked' => 3
  }
  
  def merge(mutable, to_merge)
    # MOOSE WARNING: do it!
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
    #  "options_type"  => ["none", "multiple_choice", "min_max"],
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
      errors.add(:coverage_category, "must be 'limit', or 'deductible'") unless ['coverage', 'deductible'].include?(cov["category"])
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
    # MOOSE WARNING: add errors for invalid rules (but right now only there's no rule customization, just valid seeds)
  end
  
  # options should be a copy of self.coverage_options, or the same with parents merged in
  # selections should be an array of hashes of the form { 'category'=>cat, 'uid'=>uid, 'selection'=>sel }, where sel is the # selected if applicable, and otherwise true or false
  def annotate_options(selections, options = self.coverage_options, skip_copy: false)
    # copy options
    options = Marshal.load(Marshal.dump(options)) unless skip_copy
    # apply rules to get asserts
    asserts = []
    execute(self.rules, selections: selections, asserts: asserts)
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
        refine_options!(option['options_type'], option['options'], assert['value'])
      end
    end
    # done
    return options
  end
  
  def refine_options!(options_type, options, asserts)
    case options_type
      when 'multiple_choice'
        options.map!{|opt| opt }
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
  #   array of hashes of the form { 'category'=>cat, 'uid'=>uid, '
  def execute(code, options, selections: [], asserts: false)
    case code
      when ::Array
        case code[0]
          when '='
            throw 'invalid_assert_placement' unless asserts
            if code[1].class == ::Array
              if code[1][0] == 'requirement'
                # get what to assign and what to assign it to
                category = execute(code[1][1])
                uid = execute(code[1][2])
                value = execute(code[2])
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
                category = execute(code[1][1])
                uid = execute(code[1][2])
                value = execute(code[2])
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
                throw 'invalid_assert_subject_code'
              end
            else
              throw 'invalid_assert_subject_value'
            end
          when '?', 'if'
            execute(code[1]) ? execute(code[2], asserts: asserts) : execute(code[3], asserts: asserts)
          when '&&'
            (1...code.length).inject(true){|s,i| break false unless execute(code[i], asserts: asserts); true }
          when '||'
            (1...code.length).inject(false){|s,i| break true if execute(code[i], asserts: asserts); false }
          when '|'
            (1...code.length).inject([]){|s,i| temp = execute(code[i]); s += (temp.class == ::Array ? temp : [temp]) }
          when '[]', '()', '[)', '(]'
            { 'interval' => code[0], 'start' => num(execute(code[1])), 'end' => num(execute(code[2])) }
          when '=='
            (num(execute(code[1])) - num(execute(code[2]))).abs <= (num(code[3]) || 0)
          when '<'
            (num(execute(code[1])) - num(execute(code[2]))) < (num(code[3]) || 0)
          when '>'
            (num(execute(code[1])) - num(execute(code[2]))) > -(num(code[3]) || 0)
          when '<='
            (num(execute(code[1])) - num(execute(code[2]))) <= (num(code[3]) || 0)
          when '>='
            (num(execute(code[1])) - num(execute(code[2]))) >= -(num(code[3]) || 0)
          when 'selected'
            selections.find{|s| s['category'] == execute(code[1]) && s['uid'] == execute(code[2]) } ? true : false
          when 'requirement'
            found = options.find{|s| s['category'] == execute(code[1]) && s['uid'] == execute(code[2]) }
            if found.nil?
              REQUIREMENT_TYPES['forbidden']
            else
              REQUIREMENT_TYPES[found['requirement'] || 'forbidden']
            end
          when 'value'
            found = selections.find{|s| s['category'] == execute(code[1]) && s['uid'] == execute(code[2]) }
            if found.nil? || found['selection'].nil?
              throw 'no_value'
            else
              found['selection']
            end
          when '+'
            num(execute(code[1])) + num(execute(code[2]))
          when '-'
            num(execute(code[1])) - num(execute(code[2]))
          when '*'
            num(execute(code[1])) * num(execute(code[2]))
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
end
