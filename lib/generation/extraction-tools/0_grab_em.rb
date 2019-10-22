require File.join(__dir__, '/hash_manipulation_tools.rb')


# DEFINE UTILITIES

$show_debug_stuff = false

# warning logger
$logged_warnings = []
def log_warning(summary, description = nil, longform_data = nil)
  $logged_warnings.push({ summary: summary, description: description, longform_data: longform_data })
  puts "WARNING(#{$logged_warnings.size - 1}): #{summary}#{description.nil? ? "" : "; #{description}"}#{longform_data.nil? ? "" : " (extra data available)"}"
end

# sort string grabber
def get_sort_string(a_name, a_data)
  to_return = ""
  ref = eval("::#{a_data[:source_model]}").reflections[a_name.to_s]
  case ref
    when ActiveRecord::Reflection::ThroughReflection
      to_return = ref.chain.reverse.map{|r| r.name.to_s }.join("_")
    else
      to_return = a_name.to_s
  end
  return to_return
end

# association data extractor
def extract_association_data(a_name, a_data)
  puts "      Extracting..." if $show_debug_stuff
  to_return = { source_model: a_data.active_record.name.to_sym }
  # construct association-type-specific hash
  case a_data
    when ActiveRecord::Reflection::BelongsToReflection
      to_return.merge!(a_data.polymorphic? ? {
          type: :belongs_to,
          polymorphic: true,
          foreign_key: a_data.foreign_key.to_sym,
          foreign_type: a_data.foreign_type.to_sym,
          target: [] # none specified
        } : {
          type: :belongs_to,
          polymorphic: false,
          foreign_key: a_data.foreign_key.to_sym,
          target: [a_data.class_name.to_sym] # we use an array so that in the polymorphic case we can from other sources specify a list of acceptable target model types
        })
      to_return[:autosave] = true if a_data.options[:autosave]
    when ActiveRecord::Reflection::HasOneReflection
      to_return.merge!({
        type: :has_one,
        target: [a_data.class_name.to_sym]
      })
    when ActiveRecord::Reflection::HasManyReflection
      to_return.merge!({
        type: :has_many,
        target: [a_data.class_name.to_sym]
      })
    when ActiveRecord::Reflection::ThroughReflection
      #hidden_truth = a_data.send(:delegate_reflection) # this will extract the private delgate reflection, which is way more useful than anything provided by ThroughReflection... but we don't make use of it at the moment.
      begin
        to_return.merge!({
          type: a_data.macro,
          through: a_data.options[:through],
          target: a_data.source_reflection.polymorphic? ? [] : [a_data.class_name.to_sym] # MOOSE WARNING: this is an insufficient treatment of polymorphism in through associations...
        })
      rescue
        log_warning("Hideously botched through-association discovered", "model: '#{a_data.active_record.name}'; association: '#{a_name}'; reflection: '#{a_data.name}'")
      end
    else
      # if you want to see all the reflection types used in the app, this is a convenient expression: models.map{|m| m.reflections.values }.flatten.map{|r| r.class }.uniq
      log_warning("Unhandled ActiveRecord reflection encountered", "model: '#{a_data.active_record.name}'; association: '#{a_name}'; reflection: '#{a_data.name}'")
  end
  # grab options
  to_return[:optional] = true if a_data.options[:optional]
  to_return[:as] = a_data.options[:as] unless a_data.options[:as].blank?
  to_return[:dependent] = a_data.options[:dependent] unless a_data.options[:dependent].blank?
  to_return[:autosave] = true if a_data.options[:autosave]
  # that's all, folks
  return to_return
end


# GET MODEL LIST
Rails.application.eager_load!           # eager load app (so we can see the models)
models = ApplicationRecord.descendants  # get the models
models.each{|model| model.connection }  # connect to the db (so we can see the models' fields, just in case we happen to call something that doesn't preload them itself)
models.select! do |model|
  if model.table_exists?
    true
  else
    log_warning("Model '#{model.name}' does not have a corresponding table!")
    false
  end
end

# GET FIELD AND ASSOCIATION DATA
data = {}
models.each do |model|
  m_name = model.name.to_sym
  puts "MODEL: #{m_name}" if $show_debug_stuff
  data[m_name] = { fields: {}, associations: {} }
  # get specials data for history
  if defined?(RecordChange) && model.included_modules.include?(RecordChange)
      data[m_name]['specials'] = {} unless data[m_name].has_key?('specials')
      data[m_name]['specials']['history'] = { record_change: true }
  end
  # get specials data for devise
  if defined?(DeviseTokenAuth) && defined?(DeviseTokenAuth::Concerns) && defined?(DeviseTokenAuth::Concerns::User) && model.included_modules.include?(DeviseTokenAuth::Concerns::User)
    data[m_name]['specials'] = {} unless data[m_name].has_key?('specials')
    data[m_name]['specials']['devise'] = {}
  end
  # get field info
  puts "  FIELDS:" if $show_debug_stuff
  model.columns_hash.each do |c_name, c_data|
    puts "    COLUMN: #{c_name}" if $show_debug_stuff
    data[m_name][:fields][c_data.name.to_sym] = {
      name: c_data.name.to_sym,
      type: c_data.type.to_sym,
      sql_type: c_data.sql_type.to_sym
    }
    data[m_name][:fields][c_data.name.to_sym][:type] = :array if c_data.type == :jsonb && (c_data.default || "").strip == "[]"
  end
  # fix enum fields
  puts "  ENUM FIXES:" if $show_debug_stuff
  model.defined_enums.each do |e_name, e_vals|
    unless data[m_name][:fields].has_key?(e_name.to_sym)
      log_warning("Unknown enum encountered (#{m_name.to_s}##{e_name})")
    else
      data[m_name][:fields][e_name.to_sym][:type] = :enum
      data[m_name][:fields][e_name.to_sym][:enum_values] = Marshal.load(Marshal.dump(e_vals))
    end
  end
  # get association info
  puts "  ASSOCIATIONS:" if $show_debug_stuff
  model.reflections.each do |a_name, a_data|
    puts "    ASSOC: #{a_name}" if $show_debug_stuff
    # fix belongs_to field data
    if a_data.class == ActiveRecord::Reflection::BelongsToReflection
      # fix key field data
      if data[m_name][:fields][a_data.foreign_key.to_sym].nil?
        log_warning("Non-existent belongs_to key encountered (#{m_name.to_s}##{a_data.foreign_key} from relation '#{a_name}')")
      else
        data[m_name][:fields][a_data.foreign_key.to_sym][:type] = :belongs_to_key
        data[m_name][:fields][a_data.foreign_key.to_sym][:association_name] = a_name.to_sym
      end
      # fix type field data, if applicable
      if a_data.polymorphic?
        if data[m_name][:fields][a_data.foreign_type.to_sym].nil?
          log_warning("Non-existent belongs_to type encountered (#{m_name.to_s}##{a_data.foreign_type} from relation '#{a_name}')")
        else
          data[m_name][:fields][a_data.foreign_type.to_sym][:type] = :belongs_to_type
          data[m_name][:fields][a_data.foreign_type.to_sym][:association_name] = a_name.to_sym
        end
      end
    end
    data[m_name][:associations][a_name.to_sym] = extract_association_data(a_name, a_data)
  end
  # get accepts_nested_attributes_for data
  model.nested_attributes_options.each do |na_name, na_options|
    if data[m_name][:associations].has_key?(na_name.to_sym)
      data[m_name][:associations][na_name.to_sym]['accepts_nested_attributes'] = true
      data[m_name][:associations][na_name.to_sym]['nested_attributes_options'] = na_options
    else
      log_warning("Nested attributes options exist for #{m_name.to_s}##{na_name}, an association which does not exist!")
    end
  end
  # alphabetize stuff
  data[m_name][:fields] = data[m_name][:fields].sort.to_h
  data[m_name][:associations] = data[m_name][:associations].sort_by do |k,v|
    get_sort_string(k, v)
  end.to_h
end

# alphabetize stuff & put all our model data under a "models" key
data = { models: data.sort.to_h }


# SPIT OUT THE HASH
File.open(File.join(__dir__, "app-data/scheme.json"), "w") do |f|
  f.write(JSON.pretty_generate(data))
end
