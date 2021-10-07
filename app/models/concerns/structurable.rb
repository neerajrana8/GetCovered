# =Structurable Concern
# file: +app/models/concerns/structurable.rb+

module Structurable
  extend ActiveSupport::Concern
  
  # attaches hash of errors from class methods to this particular model instance
  def apply_errors_from_hash(error_hash, base_base: [])
    error_hash.each do |error_base, error_list|
      if error_list.class == ::Hash
        apply_errors_from_hash(error_list, base_base: base_base + [error_base])
      else
        more = (error_list.last.class == ::Hash ? error_list.pop : nil)
        error_list.each{|error_list_entry| errors.add((base_base + [error_base]).join("::").to_sym, error_list_entry) }
        apply_errors_from_hash(more, base_base: base_base + [error_base]) unless more.nil?
      end
    end
  end
  
  module ClassMethods
    ####################################################################
    ################### DATA STRUCTURE STUFF ###########################
    ####################################################################
    # A structure is a hash of elements with entries like:
    #
    # 'category' => {
    #  'required' => true,
    #  'validity' => ['coverage', 'deductible'],
    #  'default_overridability' => 0
    # }
    #
    # You can also specify 'default_value'. For now, look at the get_whatever methods below
    # to understand them in more detail. The "nil" options there are what happens if one is omitted.
    # The parameters for all of them, in order, are:
    #   1) the value of the corresponding key in the structure hash
    #   2) the value of the corresponding key in the data hash
    #   3) the hash immediately containing the corresponding key in the data hash
    #   4) the root data hash (an ancestor of param #3)
    #   5) an array of keys used to go from param #4 to param #2;
    #      when the object in question is a hash, the value is its key;
    #      when it is an array, the value is a hash which will yield the element
    #      if you feed it to the_array.find{|x| param_5.all?{|k,v| x[k] == v } }.
    # 
    # The following are keys you need to add for special data types:
    #
    #   special: 'array', # an array of structures
    #   special_data: {
    #     identity_keys: array of keys to be used to identify elements in different data hashes,
    #     structure: the structure of the array elements
    #   }
    #
    #   special: 'hash',  # a hash whose keys are structures
    #   special_data: {
    #     keys: (optional) array of allowed keys (omit/set to nil to allow free keys),
    #     structure: the structure of the hash values,
    #     structure_by_key: (optional) hash mapping specific keys to structures; will fall back to structure when a key is not in the hash
    #   }
    
    # get default value
    def get_default_value(default_value, value, datum, data_root, path)
      case default_value
        when ::Proc
          return get_default_value(default_value.call(value, datum, data_root, path), value, datum, data_root, path)
      end
      return default_value
    end
    
    # get whether a data structure element is required
    def get_required(required, value, datum, data_root, path)
      case required
        when ::TrueClass, ::FalseClass, ::NilClass
          return required == true
        when ::Proc
          return get_required(required.call(value, datum, data_root, path), value, datum, data_root, path)
        when 'absolutely'
          return 'absolutely'
      end
      return false
    end
    
    # get whether a data structure element is valid
    def get_validity(validity, value, datum, data_root, path)
      case validity
        when ::Array
          return validity.include?(value) ? nil : "has an invalid value"
        when ::Proc
          return get_validity(validity.call(value, datum, data_root, path), value, datum, data_root, path)
        when ::TrueClass, ::FalseClass, ::NilClass
          return validity == false ? "has an invalid value" : nil
        when ::String
          return validity
      end
      return "has an invalid value"
    end
    
    # get a data structure element's default overridability
    def get_default_overridability(default_overridability, value, datum, data_root, path)
      case default_overridability
        when ::NilClass, ::Integer
          return default_overridability
        when ::Proc
          return get_default_overridability(default_overridability.call(value, datum, data_root, path), value, datum, data_root, path)
      end
      return nil
    end
    
    # get a data structure's overridability ceiling
    def get_overridability_ceiling(data)
      ceiling = 0
      if data.class == ::Hash
        data.each do |k,v|
          if k == 'overridabilities_' && v.class == ::Array
            m = v.select{|o| o.class == ::Integer }.max
            ceiling = m if m > ceiling
          else
            if v.class == ::Hash || v.class == ::Array
              m = get_overridability_ceiling(v)
              ceiling = m if m > ceiling
            end
          end
        end
      elsif data.class == ::Array
        data.each do |v|
          if v.class == ::Hash || v.class == ::Array
            m = get_overridability_ceiling(v)
            ceiling = m if m > ceiling
          end
        end
      end
      return ceiling
    end
    
    # Validate (and/or fix) a data structure.
    # params:
    #   structure:
    #     (hash):     a hash defining the structure data should conform to
    #   data:
    #     (hash):     a hash of data to be validated
    #   strict:
    #     false:      ignore missing non-absolutely required elements
    #     true:       add errors when non-absolutely required elements are missing
    #     (none):     defaults to false
    #   apply_defaults:
    #     false:      leave missing elements missing
    #     true:       replace missing required elements when strict=true or they are absolutely required
    #     absolutely: replace missing elements whenever they are required, regardless of strict and absoluteness
    #     (none):     defaults to true
    #   apply_default_overridabilities:
    #     false:      add errors when overridabilities are missing
    #     (truthy):   insert default overridabilities when overridabilities are missing
    #     (none):     let value be the same as apply_defaults
    #   defaultize_invalid_overridabilities:
    #     false:      add errors when overridabilities are invalid
    #     (truthy):   replace invalid overridabilities with default overridabilities
    #     (none):     let value be the same as apply_default_overridabilities
    #   preserve_mystery_keys:
    #     false:      remove keys not recorded in the structure
    #     true:       preserve keys not recorded in the structure
    #     (none):     defaults to false
    #   errors:
    #     (hash):     errors will be stored in this hash: { key_in_data: [error_string_1, ...] },
    #                 where each array will optionally end with a hash of format { subkey: another_hash_of_the_same_format_as_errors }
    #                 (this is for entries with subkeys, in case they have errors of their own)
    #     (none):     errors will be discarded after execution
    #   data_root:
    #     (hash):     the original data value before any recursion (this is used internally, you should ignore it)
    #     (none):     defaults to data
    #   path:
    #     (array):    array of keys representing the recursion path from data_root to data (this is used internally, you should ignore it)
    #     (none):     defaults to []
    # returns:
    #   a hash to replace data with if you want to eliminate/reduce errors;
    #   this will be identical to data, but with any defaults added or fixes made allowed by the params
    def validate_data_structure(data, structure,
      strict: false,
      apply_defaults: true,
      apply_default_overridabilities: apply_defaults,
      defaultize_invalid_overridabilities: apply_default_overridabilities,
      preserve_mystery_keys: false,
      errors: {},
      data_root: data,
      path: []
    )
      # set up useful variables
      nested_errors = {}
      dovers = (data['overridabilities_'] || {})
      rovers = {}
      stdargs_base = [data, data_root]
      result = {'overridabilities_' => rovers}
      # validate the data structure
      structure.each do |prop, struc|
        stdargs = [data[prop], *stdargs_base, path + [prop]]
        # handle missing entries
        if data.has_key?(prop)
          result[prop] = data[prop]
        else
          required = get_required(struc['required'], *stdargs)
          case required
            when false
              next
            else # required is true or 'absolutely'
              if strict || required == 'absolutely'
                # gotta apply defaults or flee
                if apply_defaults && struc.has_key?('default_value')
                  result[prop] = get_default_value(struc['default_value'], *stdargs) # MOOSE WARNING: get_default_value undefined, 'default_value' never occurs
                else
                  (errors[prop] ||= []).push("is missing but is a required value")
                  next
                end
              else
                # only apply defaults if forced, otherwise flee
                if apply_defaults == 'absolutely' && struc.has_key?('default_value')
                  result[prop] = get_default_value(struc['default_value'], *stdargs)
                else
                  next
                end
              end
          end
        end # at this point, result[prop] is known to exist
        # validate/set overridability
        if dovers.has_key?(prop)
          if dovers[prop].nil? || (dovers[prop].class == ::Integer && dovers[prop] >= 0) || dovers[prop] == Float::INFINITY
            rovers[prop] = dovers[prop]
          else
            if defaultize_invalid_overridabilities
              rovers[prop] = get_default_overridability(struc['default_overridability'], *stdargs)
            else
              (errors[prop] ||= []).push("has invalid overridability setting '#{dovers[prop]}'")
            end
          end
        else
          if apply_default_overridabilities
            rovers[prop] = get_default_overridability(struc['default_overridability'], *stdargs)
          else
            (errors[prop] ||= []).push("has no overridability setting")
          end
        end
        # handle specials (we use result, not data, because result[prop] = data[prop] or the default value)
        case struc['special']
          when 'hash'
            if result[prop].class == ::Hash
              # remove invalid keys
              unless struc['special_data']&.[]('keys').blank?
                invalid_keys = result.keys & struc['special_data']['keys']
                unless invalid_keys.blank?
                  (errors[prop] ||= []).push("has invalid keys #{invalid_keys.map{|ik| "'#{ik}'" }.join(", ")}")
                  result[prop] = result[prop].select{|k,v| !invalid_keys.include?(k) }
                end
              end # now we're assured we have only valid keys
              # recurse into hash entries
              result[prop] = result[prop].map do |k,v|
                path_key = k
                rez_errors = {}
                rez = validate_data_structure(v, struc['special_data']['structure_by_key']&.[](k) || struc['special_data']['structure'],
                  strict: strict,
                  apply_defaults: apply_defaults,
                  apply_default_overridabilities: apply_default_overridabilities,
                  defaultize_invalid_overridabilities: defaultize_invalid_overridabilities,
                  preserve_mystery_keys: preserve_mystery_keys,
                  errors: rez_errors,
                  data_root: data_root,
                  path: path + [prop, path_key]
                )
                unless rez_errors.blank?
                  (nested_errors[prop] ||= {})[path_key] = rez_errors
                end
                next [k, rez]
              end.to_h
            end
          when 'array'
            if result[prop].class == ::Array
              # recurse into array entries
              result[prop] = result[prop].map do |v|
                path_key = struc['special_data']['identity_keys'].map{|ik| [ik, v[ik]] }.to_h
                rez_errors = {}
                rez = validate_data_structure(v, struc['special_data']['structure'],
                  strict: strict,
                  apply_defaults: apply_defaults,
                  apply_default_overridabilities: apply_default_overridabilities,
                  defaultize_invalid_overridabilities: defaultize_invalid_overridabilities,
                  preserve_mystery_keys: preserve_mystery_keys,
                  errors: rez_errors,
                  data_root: data_root,
                  path: path + [prop, path_key]
                )
                unless rez_errors.blank?
                  path_key = "(#{struc['special_data']['identity_keys'].map{|ik| "'#{ik}'='#{rez[ik]}'" }.join(",")})" # we recalc the path key in case it changed
                  (nested_errors[prop] ||= {})[path_key] = rez_errors
                end
                next rez
              end
            end
          else
            # nothing to do here
        end
        # validate our value
        validity = (get_validity(struc['validity'], *stdargs) rescue "has an invalid value")
        unless validity.nil?
          (errors[prop] ||= []).push(validity)
        end
      end # </validate the data structure>
      # append any nested errors to the appropriate error entry
      nested_errors.each do |prop, suberrors|
        (errors[prop] ||= []).push(suberrors)
      end
      # all done!
      return preserve_mystery_keys ? data.merge(result) : result
    end
    
    
    
    # Merge data structures.
    #   structure: hash describing data structure schema
    #   datas: array of exemplars of the provided structure
    #   overridability_offsets: an array of offsets so that the nth element of datas has innate overridability level overridability_offsets[n]
    #     pass an array: it will use that array (make sure it's the same length as datas, it doesn't check!)
    #     pass an integer: it will use that integer for all offsets
    #     pass Float::INFINITY: it will use Float::INFINITY for all offsets (this will result in ALL overridabilities being set to infinity!)
    #     leave blank or pass nil: will use the index of each data as its offset
    def merge_data_structures(datas, structure, overridability_offsets = (0...datas.length).to_a, union_mode: false)
      # convert shorthand overridability_offset value into an array if needed
      case overridability_offsets
        when ::Integer
          overridability_offsets = (0...(datas.length)).map{|n| overridability_offsets }
        when Float::INFINITY
          overridability_offsets.map{|oo| oo || Float::INFINITY }
        when nil
          overridability_offsets = (0...datas.length).to_a
      end
      result = { 'overridabilities_' => {} }
      # in union mode, we need to process overridability offset groups, so we sort the input to make those groups contiguous
      if union_mode && union_mode != 'sorted'
        datas.sort_by!.with_index{|datum,index| overridability_offsets[index] }
        overridability_offsets.sort! 
        union_mode = 'sorted' # still truthy, but lets us know to skip this in recursive calls
      end
      structure.each do |prop, struc|
        case struc['special']
          when 'hash'
            # collect valid keys to the hash, ignoring elements whose insertion is forbidden
            insertion_requirement = result['overridabilities_'][prop] || Float::INFINITY
            keys = []
            group_offset = nil # for union mode
            group_requirement = nil # for union mode
            datas.each.with_index do |data, data_index|
              next if !data.has_key?(prop)
              data_insertion_requirement = (data['overridabilities_']&.[](prop) || Float::INFINITY) + overridability_offsets[data_index]
              next unless insertion_requirement >= data_insertion_requirement
              if union_mode
                if group_offset == overridability_offsets[data_index]
                  # within an offset group, we track the least restrictive (largest) overridability
                  group_requirement = data_insertion_requirement if data_insertion_requirement > group_requirement
                else
                  # we've rolled over into a new offset group; new entries can be inserted only if they can override the least restrictive overridability in the previous groups 
                  next unless group_requirement.nil? || insertion_requirement >= group_requirement # ir is about to be = to gr; this entry would fail the overridability test; so don't count it as a valid rollover, just continue to the next
                  insertion_requirement = group_requirement if group_requirement&.<(insertion_requirement)
                  group_requirement = data_insertion_requirement
                  group_offset = overridability_offsets[data_index]
                end
              end
              keys.concat(data[prop].keys).uniq!
              insertion_requirement = data_insertion_requirement unless union_mode
            end
            insertion_requirement = group_requirement if union_mode && group_requirement&.<(insertion_requirement)
            keys.select!{|k| struc['special_data']['keys'].include?(k) } unless struc['special_data']['keys'].nil?
            result['overridabilities_'][prop] = insertion_requirement
            # merge hash elements
            result[prop] = {}
            keys.each do |k|
              nested_structure = struc['special_data']&.[]('structure_by_key')&.[](k) || struc['special_data']['structure']
              next if nested_structure.nil?
              merged_element = merge_data_structures(datas.map{|d| (d[prop] || {})[k] || {} }, nested_structure, overridability_offsets, union_mode: union_mode)
              result[prop][k] = merged_element unless merged_element.blank?
            end
          when 'array'
            # group elements by identity keys
            identity_keys = struc['special_data']['identity_keys'] # get keys which we use to identify array elements with one another
            grouped_datas = datas.map{|d| (d[prop] || []).group_by{|e| identity_keys.map{|ik| e[ik] } }.transform_values{|vals| vals.first } } # group each array by identity keys
            # collect identity keys, ignoring elements whose insertion is forbidden
            insertion_requirement = result['overridabilities_'][prop] || Float::INFINITY
            identity_keys = [] # now we're going to use this to store the full list of element identities instead of the keys that generate them
            group_offset = nil # for union mode
            group_requirement = nil # for union mode
            grouped_datas.each.with_index do |gd, gd_index|
              gd_insertion_requirement = (datas[gd_index]['overridabilities_']&.[](prop) || Float::INFINITY) + overridability_offsets[gd_index]
              next unless insertion_requirement >= gd_insertion_requirement
              if union_mode # see hash handling above for comments on this block; it is identical except with the prefix data_ instead of gd_
                if group_offset == overridability_offsets[gd_index]
                  group_requirement = gd_insertion_requirement if gd_insertion_requirement > group_requirement
                else
                  next unless group_requirement.nil? || insertion_requirement >= group_requirement
                  insertion_requirement = group_requirement if group_requirement&.<(insertion_requirement)
                  group_requirement = gd_insertion_requirement
                  group_offset = overridability_offsets[gd_index]
                end
              end
              identity_keys.concat(gd.keys).uniq!
              insertion_requirement = gd_insertion_requirement unless union_mode
            end
            insertion_requirement = group_requirement if union_mode && group_requirement&.<(insertion_requirement)
            result['overridabilities_'][prop] = insertion_requirement
            # merge array elements
            extant_grouped_datas = grouped_datas.map.with_index{|gd, gd_index| datas[gd_index][prop].nil? ? nil : gd }
            result[prop] = []
            identity_keys.each do |ik|
              # skip if removal condition is met
              if union_mode
                # skip entire removal process in union mode. the logic below is sensitive to union_mode so as to not remove things in some instances, but better to just not remove ANYTHING since the way we use union_mode has evolved.
              elsif struc['special_data']['remove_missing'] == 'different_overridabilities'
                # remove if any non-nil entry is missing ik and no entry with the same overridability possesses ik (if union_mode, also keep if an entry w the same ovrdblty is nil, since it would inherit)
                next unless (extant_grouped_datas.map.with_index do |egd, gd_index|
                  egd.nil? || egd.has_key?(ik) ? nil : (datas[gd_index]['overridabilities_']&.[](prop) || Float::INFINITY) + overridability_offsets[gd_index]
                end.compact - extant_grouped_datas.map.with_index do |egd, gd_index|
                  (egd.nil? && !union_mode) || !egd.has_key?(ik) ? nil : (datas[gd_index]['overridabilities_']&.[](prop) || Float::INFINITY) + overridability_offsets[gd_index]
                end.compact).blank?
              elsif struc['special_data']['remove_missing']
                # remove if any non-nil entry is missing ik (if union_mode, keep if at least one is nil)
                next if extant_grouped_datas.any?{|egd| !egd.nil? && !egd.has_key?(ik) } && (!union_mode || !extant_grouped_datas.any?{|egd| egd.nil? })
              end
              # merge array entries and insert
              merged_element = merge_data_structures(grouped_datas.map{|gd| gd[ik] || {} }, struc['special_data']['structure'], overridability_offsets, union_mode: union_mode)
              result[prop].push(merged_element) unless merged_element.blank?
            end
          else
            # merge scalar values
            insertion_requirement = result['overridabilities_'][prop] || Float::INFINITY
            group_offset = nil # for union mode
            group_requirement = nil # for union mode
            datas.each.with_index do |data, data_index|
              next if !data.has_key?(prop)
              data_insertion_requirement = (data['overridabilities_']&.[](prop) || Float::INFINITY) + overridability_offsets[data_index]
              next unless insertion_requirement >= data_insertion_requirement
              if union_mode
                if group_offset == overridability_offsets[data_index]
                  group_requirement = data_insertion_requirement if data_insertion_requirement > group_requirement
                else
                  next unless group_requirement.nil? || insertion_requirement >= group_requirement
                  insertion_requirement = group_requirement if group_requirement&.<(insertion_requirement)
                  group_requirement = data_insertion_requirement
                  group_offset = overridability_offsets[data_index]
                end
                if struc['union'] && result.has_key?(prop)
                  result[prop] = struc['union'].call(result[prop], prop)
                else
                  result[prop] = data[prop]
                end
              else
                result[prop] = data[prop]
              end
              insertion_requirement = data_insertion_requirement unless union_mode
            end
            insertion_requirement = group_requirement if union_mode && group_requirement&.<(insertion_requirement)
            result['overridabilities_'][prop] = insertion_requirement
        end
      end
      return result
    end
    
    # strip out overridability info
    def remove_overridability_data!(thang)
      case thang
        when ::Hash
          thang.delete('overridabilities_')
          thang.transform_values!{|v| remove_overridability_data!(v) }
        when ::Array
          thang.map!{|v| remove_overridability_data!(v) }
      end
      return thang
    end
    
    
  end # end class methods
end # end concern
