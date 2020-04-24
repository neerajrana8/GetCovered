# set configurable globals
$file_open_command = ENV['RBMETA_FILE_OPEN_COMMAND'] || "(geany '$FILENAME':$LINE_NUMBER:$COLUMN &)"
$optional_loads = (ENV['RBMETA_OPTIONAL_LOADS'] || "monkey_hash.rb,monkey_array.rb").split(",").select{|str| !str.blank? }
$enable_empirical_polymorphic_reflection_targets = (ENV['RBMETA_EMPIRICAL_POLYMORPHIC_REFLECTION_TARGETS'] || false)

# set things there's no real reason you'd want to configure
$metaroot = ENV['RBMETA_METAROOT'] || Rails.root.to_s


# load all required & selected optional files
Dir.foreach(File.join($metaroot, "lib", "meta", "required")).select{|filename| filename.end_with?(".rb") }.each do |filename|
  load File.join($metaroot, "lib", "meta", "required", filename)
end

$optional_loads.each do |cnvld|
  load File.join($metaroot, "lib", "meta", "optional", cnvld)
end

# Useful reflections processing methods

def reflection_targets(ref_data) # will miss targets of polymorphic associations which lack an inverse assoc!
  if ref_data.class == ::String
    ref_data = ref_data.split("#")
    begin
      ref_data = ref_data[0].constantize.reflections[ref_data[1]]
    rescue
      puts "Invalid association specification '#{ref_data.join("#")}' passed to reflection_targets"
      return []
    end
  end
  if ref_data.polymorphic?
    return (all_models.select{|m| m.reflections.any?{|rn,rd| rd.klass == ref_data.active_record && rd.options[:as] == ref_data.name rescue false } } + (!$enable_empirical_polymorphic_reflection_targets ? [] :
      ref_data.class == ::ActiveRecord::Reflection::BelongsToReflection ? ref_data.active_record.pluck("DISTINCT #{ref_data.foreign_type}").map{|cn| "::#{cn}".constantize } : [])).uniq
  end
  [ref_data.klass] rescue []
end

# Useful methods that pull data from the file system

def all_model_names
  Dir.foreach("#{$metaroot}/app/models").select{|mp| mp.end_with?(".rb") }.map{|mp| mp.chomp(".rb").camelize }
end

def all_models(
  concern: nil,      # class or class name of concern to require
  association: nil,  # name of assoc to require, or a hash with this format (any keys set to nil will be ignored): {
                          #   name: (required assoc name or array of allowed names),
                          #   target: (required target model or array of models; put nil in an array to accept any polymorphic assoc),
                          #   polymorphic: (true or false to require or forbid polymorphic associations),
                          #   forbid_extra_targets: (true to forbid poly assocs with targets outside the provided list, or provide an array of models/model names to forbid assocs with targets outside that list instead of the targets list),
                          #   forbid_multi_targets: (true to forbid multiple targets, even if all entries are in the list)
                          # }, or an array of such parameters (a model satisfying at least one entry in the array satisfies)
  association_hash: nil   # if you pass a hash, it will be cleared & filled with a map from the returned models to the associations that satisfied association; if you pass true, this function will return such a hash instead of the usual array of models
)
  to_return = all_model_names.map{|mn| "::#{mn}".constantize }.select{|m| !m.abstract_class }
  # concern filter
  to_return.select!{|m| m.included_modules.include?(concern.class == ::String ? concern.camelize.constantize : concern) } unless concern.nil?
  # association filter
  should_return_association_hash = false
  if association_hash.class == ::TrueClass
    association_hash = {}
    should_return_association_hash = true
  elsif association_hash.class == ::Hash
    association_hash.clear
  else
    association_hash = nil # just to be sure
  end
  unless association.nil?
    association = [association] unless association.class == ::Array
    to_return = association.map do |assoc|
      # process assoc into standardized assoc_data
      assoc_data = {
        name: nil,        # allowed names
        target: nil,      # allowed target classes
        poly: false,      # accept polymorphic assoc in lieu of target satisfaction
        polymorphic: nil, # true to require assocs be polymorphic, false to require they not be
        type: assoc[:type],        # :belongs_to, :has_one, :has_many, etc. (or nil for no restriction, or array for multiple options)
        forbid_extra_targets: assoc[:forbid_extra_targets] || false,
        forbid_multi_targets: assoc[:forbid_multi_targets] || false
      }
      if assoc.class == ::String || assoc.class == ::Symbol
        assoc_data[:name] = [assoc.to_s]
      elsif assoc.class == ::Hash
        # name
        assoc_data[:name] = assoc[:name].map{|n| n.to_s } if assoc[:name].class == ::Array
        assoc_data[:name] = [assoc[:name].to_s] if assoc[:name].class == ::String || assoc[:name].class == ::Symbol
        # target
        unless assoc[:target].nil?
          assoc_data[:target] = (assoc[:target].class == ::Array ? assoc[:target] : [assoc[:target]])
          assoc_data[:target].flatten!
          assoc_data[:target].map!{|ad| ad.class == ::String || ad.class == ::Symbol ? "::#{ad}".constantize : ad }
          if assoc_data[:target].include?(nil)
            assoc_data[:target].compact!
            assoc_data[:poly] = true
          end
        end
        # extra targets
        if assoc_data[:forbid_extra_targets].class == ::Array
          assoc_data[:forbid_extra_targets] = assoc_data[:forbid_extra_targets].map{|mn| mn.class == ::String || mn.class == ::Symbol ? "::#{mn}".constantize : mn }.compact
        end
        # polymorphic requirement
        assoc_data[:polymorphic] = (assoc[:polymorphic] ? true : false) unless assoc[:polymorphic].nil?
        # type
        assoc_data[:type] = [assoc_data[:type]] if !assoc_data[:type].nil? && assoc_data[:type].class != ::Array
      end
      # go wild
      to_return.select do |m|
        # apply constraints to reflections
        pool = m.reflections.select{|k,v| true } # make copy
        pool.select!{|rn,rd| assoc_data[:name].include?(rn) } unless assoc_data[:name].nil?
        pool.select!{|rn,rd| assoc_data[:polymorphic] == rd.polymorphic? } unless assoc_data[:polymorphic].nil?
        pool.select!{|rn,rd| assoc_data[:type].include?(rd.macro) } unless assoc_data[:type].nil?
        pool.select! do |rn,rd|
          next true if !assoc_data[:forbid_multi_targets] && assoc_data[:poly] && rd.polymorphic? # including nil in the target list allows any polymorphic assoc, unless we forbid multi-targets--then it allows any polymorphic assoc with only 1 target
          refl = reflection_targets(rd)
          next false if refl.blank? # MOOSE WARNING: fix the forbidden-multi case here
          if assoc_data[:forbid_multi_targets]
            next refl.length == 1 && (assoc_data[:poly] || assoc_data[:target].include?(refl[0]))
          elsif assoc_data[:forbid_extra_targets]
            next (refl & (assoc_data[:forbid_extra_targets].class == ::Array ? assoc_data[:forbid_extra_targets] : assoc_data[:target])).length == refl.length
          end
          next !(refl & assoc_data[:target]).blank?
        end unless assoc_data[:target].nil?
        # see if any reflections worked
        next false if pool.blank?
        unless association_hash.nil?
          association_hash[m.name] = [] unless association_hash.has_key?(m.name)
          association_hash[m.name] += pool.keys
          association_hash[m.name].uniq!
        end
        true
      end
    end.flatten.uniq
  end
  return should_return_association_hash ? association_hash : to_return
end

def subfolders_of(reldir)
  Dir.glob(File.join($metaroot, reldir, "**/"))
end

def source_from(reldir, recursive: false, filetypes: ['rb'])
  reldir = reldir.chomp("/")
  to_return = {}
  (recursive ? subfolders_of(reldir) : [File.join($metaroot, reldir)]).each do |curdir|
    Dir.foreach(curdir).select{|mp| mp.end_with?(*filetypes.map{|ft| ".#{ft}" }) }.each do |mp|
      to_return[File.join(curdir, mp).delete_prefix($metaroot).delete_prefix("/")] = File.read(File.join(curdir, mp))
    end
  end  
  return to_return
end

# Convenience methods for grabbing file sources (format: { filename_relative_to_rails_root => source_string })

def model_source(**args)
  source_from("app/models", **({recursive: false}.merge(args)))
end
alias models_source model_source
alias model_sources model_source
alias models_sources model_source

def controller_source(**args)
  source_from("app/controllers", **({recursive: true}.merge(args)))
end
alias controllers_source controller_source
alias controller_sources controller_source
alias controllers_sources controller_source

def job_source(**args)
  source_from("app/jobs", **({recursive: true}.merge(args)))
end
alias jobs_source job_source
alias job_sources job_source
alias jobs_sources job_source

def service_source(**args)
  source_from("app/services", **({recursive: true}.merge(args)))
end
alias services_source service_source
alias service_sources service_source
alias services_sources service_source

def interaction_source(**args)
  source_from("app/interactions", **({recursive: true}.merge(args)))
end
alias interactions_source interaction_source
alias interaction_sources interaction_source
alias interactions_sources interaction_source

def seed_source(**args)
  source_from("db/seeds", **({recursive: true}.merge(args)))
end
alias seeds_source seed_source
alias seed_sources seed_source
alias seeds_sources seed_source

def view_source(**args)
  source_from("app/views/v2", **({recursive: true, filetypes: ['jbuilder']}.merge(args)))
end
alias views_source view_source
alias view_sources view_source
alias views_sources view_source

# MOOSE WARNING: MISSING MAILERS

# excludes seeds & views
def app_source(models: true, controllers: true, jobs: true, services: true, interactions: true, # default to true
               views: false, seeds: false, # default to false
               all: false) # convenience param to force all true without writing them all
  {}.merge(models || all ? model_source(recursive: true) : {})
    .merge(controllers || all ? controller_source(recursive: true) : {})
    .merge(jobs || all ? job_source(recursive: true) : {})
    .merge(services || all ? service_source(recursive: true) : {})
    .merge(interactions || all ? interaction_source(recursive: true) : {})
    .merge(views || all ? view_source(recursive: true) : {})
    .merge(seeds || all ? seed_source(recursive: true) : {})
end

# Find method: give it a block that takes |line[, full_source_string]| as input & returns a truthy value iff the line satisfies what you're looking for;
#   returns { filename => { line_number => { snippet: the_line_of_source, result: the_result_of_the_block } } };
# If your block returns an integer, it will be interpreted as the column where the occurrence was found by methods like open_findings that can make use of column info.

def find_where(
  source = nil,           # [optional] a source object (i.e. a filename -> source string hash), or nil to default to app_source, or :all to default to app_source(all: true)
  what = nil,             # if string provided, overrides block; searches for the provided string
  calls: nil,             # replaces &block; put a list of model names separated by "/", then a "#", then a list of methods separated by "/", to search for occurrences of invocations of that method upon any of those models. Not guaranteed to be 100% perfect (it will miss local variable calls and may pull in extra calls based on polymorphic associations), but it's pretty close
  cautious: true,         # set to false in combination with a :calls argument in order to exclude results where a method you're looking for is called through a polymorphic association that might lead to a model you aren't interested in
  multiline: false,       # multiline search; not supported
  &block                  # block taking strings |current_line, whole_file| and returning a truthy value if satisfied; if it returns an integer, it will be interpreted as the column where the occurrence was found when the results are passed to methods like open_findings that can make use of column info
)
  warnings = []
  # flee from freakish errors
  if multiline
    puts "NO MULTILINE SUPPORT YET"
    return {}
  end
  # fix parameters if source was not provided but what was
  if what.nil? && source.class == ::String
    what = source
    source = nil
  end
  # handle special queries
  unless what.nil? && what.class == ::String
    block = Proc.new{|line,src| line.index(what) }
  end
  unless calls.nil?
    mode = calls.scan("#").count == 1 ? '#' : calls.scan("::").count == 1 ? '::' : calls.scan(":").count == 1 ? ':' : nil
    if mode.nil?
      puts "UNSUPPORTED PARAMETER FORMAT FOR 'calls'; SORRY AMIGO"
      return {}
    end
    warnings.push("This method does not currently trace aliases/local variables; the following is not guaranteed to be a complete list!")
    splat = calls.split(mode).map{|a| a.split('/') }
    splat = splat[0].map do |model_name|
      (
        (case mode; when '::',':'; [model_name.singularize.camelize]; else; []; end) + # if we're a class method, we might be called on the class directly
        all_models(association_hash: true, association: {
          target: model_name.singularize.camelize,                # we want assocs whose target is the given model
          forbid_extra_targets: cautious ? false : splat[0],      #                and whose targets are all among the given models, if we are incautious
          type: case mode; when '::'; [:has_many, :has_and_belongs_to_many]; when '#'; [:belongs_to, :has_one]; else; nil; end   # and if we're a class method, we might be callable on ActiveRecord collections, but not on singletons
        }).values.flatten
      ).uniq.map{|model_ref| splat[1].map{|meth| "#{model_ref}.#{meth}" } }.flatten # we've got an array of strings the methods might be called on; now append the methods
    end.flatten.uniq  # combine our callble strings across all provided models
    # MOOSE WARNING: change this when you improve the block argument list
    block = Proc.new {|line,src| splat.inject(nil){|found, quarry| found || line.index(quarry) } }
  end
  # flee if there's still no block
  return {} if block.nil?
  # get files
  if source.nil? || source == :default
    source = app_source
  elsif source == :all
    source = app_source(all: true)
  end
  # go wild
  result = nil
  source.transform_values do |v|
    lines = v.split("\n")
    satisfying = {}
    lines.each.with_index do |line, index|
      if(result = block.call(line, v))
        satisfying[index+1] = { snippet: line, result: result }
      end
    end
    satisfying.length == 0 ? nil : satisfying
  end.compact
end

def print_findings(findings)
  findings.each do |where, what|
    puts where
    what.each do |line_no, line_co|
      puts "  #{line_no}: \t #{line_co[:snippet].strip}"
    end
  end
  return nil
end

def open_findings(findings) # only opens one finding per file (the first one)
  findings.each do |where, what|
    openf(where, what.first[0], what.first[1][:result].is_a?(Integer) ? what.first[1][:result] : nil)
  end
  return nil
end


def openf(filename, line_number = nil, column = nil)
  `#{$file_open_command.gsub("$FILENAME", filename.start_with?($metaroot) ? filename : File.join($metaroot, filename)).gsub("$LINE_NUMBER", (line_number || 1).to_s).gsub("$COLUMN", (column || 0).to_s)}`
end
