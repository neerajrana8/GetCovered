class InsurableRateConfiguration < ApplicationRecord
  belongs_to :configurable, polymorphic: true
  belongs_to :configurer, polymorphic: true
  belongs_to :carrier
  
  def validate_coverage_options
    # Coverage schema:
    #{
    #  "category"      => 'coverage' or 'deductible',
    #  "uid"           => string,
    #  "title"         => string,
    #  "description"   => string (optional)",
    #  "requirement"   => boolean or nil,
    #  "options_type"  => ["none", "multiple_choice", "min_max"],
    #  "options"       => depends on options_type:
    #     none: omittable,
    #     multiple_choice: array of numerical values
    #     min_max: { min: number, max: number, step: +number }, with step optional & defaulting to 1 only if min & max are both integers
    #}
    self.coverage_options.each.with_index do |cov,i|
      disp_title = cov["title"].blank? ? "coverage option ##{i}" : cov["title"]
      errors.add(:coverage_title, "cannot be blank (#{disp_title})") if cov["title"].blank?
      errors.add(:coverage_uid, "cannot be blank (#{disp_title})") if cov["uid"].blank?
      # description can be blank
      errors.add(:coverage_requirement, "must be true (required), false (disabled), or null (optional) (#{disp_title})") unless [true,false].include?(cov["requirement"])
      errors.add(:coverage_cateogry, "must be 'limit', or 'deductible'") unless ['coverage', 'deductible'].include?(cov["category"])
      case cov["options_type"]
        when "none"
          # all good
        when "multiple_choice"
          errors.add(:coverage_options, "must be a set of numerical options (#{disp_title})") unless cov["options"].class == ::Array # MOOSE WARNING: check numericality
        when "min_max"
          if cov["options"].class !== ::Hash
            erros.add(:coverage_options, "must specify min/max values (#{disp_title})")
          elsif !cov["options"]["min"]
            errors.add(:coverage_options, "must specify min (#{disp_title})")
          elsif !cov["options"]["max"]
            errors.add(:coverage_options, "must specify max (#{disp_title})")
          elsif cov["options"]["min"].to_f > cov["options"]["max"].to_f
            errors.add(:coverage_options_min, "cannot exceed max (#{disp_title})")
          elsif cov["options"]["step"].nil? && (cov["options"]["min"] % 1 != 0 || cov["options"]["max"] % 1 != 0)
            errors.add(:coverage_options, "must specify step for non-integer min and max values (#{disp_title})")
          elsif !cov["options"]["step"].nil? && cov["options"]["step"].to_f <= 0
            errors.add(:coverage_options, "step must be greater than 0 (#{disp_title})")
          end
        else
          errors.add(:coverage_options_type, "must be 'none', 'multiple_choice', or 'min_max' (#{disp_title})")
      end
    end
  end
  
  def validate_rules
    #Rules schema:
    #{
    #  "message" => string,           # human-readable rule description
    #  "option_category" => string,   # the category of the 
    #  "option_uid" => string,
    #  "code" => recursive combination of [operator, ...arguments] arrays
    #}
    
    
  end
  
  def annotate_options(selections)
    # selections should be a hash of form { uid => true (selected)/false(not selected)/some # (for the selected option) }
    to_return = self.coverages.map do |cov|
      
    end
  end
  
  # params:
  #   selections: an array of hashes of the form { 'category'=>cat, 'uid'=>uid, 'selection'=>sel }, where sel is the # selected if applicable, and otherwise true or false
  #   asserts: internal use, keeps track of where in the syntax asserts are allowed (false if not allowed, array of asserts if allowed)
  # returns:
  #   array of hashes of the form { 'category'=>cat, 'uid'=>uid, '
  def execute(code, selections: [], asserts: false)
    case code
      when ::Array
        case code[0]
          when '='
            throw 'invalid_assert_placement' unless asserts
            if code[1].class == ::Array
              if code[1][0] == 'selected'
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
                asserts[index]['selected'] = [] if asserts[index]['selected'].nil?
                asserts[index]['selected'].push(value)
                asserts[index]['selected'].uniq!
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
            { interval: code[0], start: num(execute(code[1])), end: num(execute(code[2])), step: code[3].nil? ? nil : num(execute(code[3])) }
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
          when 'value'
            found = selections.find{|s| s['category'] == execute(code[1]) && s['uid'] == execute(code[2]) }
            if found.nil?
              throw 'no_value'
            else
              found
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
        val.to_d
      else # MOOSE WARNING: are there other possibilities besides numeric?
        val.to_d
    end
  end
  
end
