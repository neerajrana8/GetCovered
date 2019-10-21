require "json"

class FromHashGenerator < Rails::Generators::Base
  desc "This generator produces views, controllers, and routes in accordance with a provided JSON or Ruby hash file."
  class_option :filename, type: :string
  class_option :views, type: :string
  class_option :controllers, type: :string
  source_root File.expand_path("../templates", __FILE__)

  def init
    @scheme = {}
    # logging variables
    @errors = []
    @gputs_indentation = 0
    # command-line options
    @generate_views_for = nil
    @generate_controllers_for = nil
    @force = true
    @strict_order_permissions = false # true: filter permissions don't imply sort permissions; false: filter permissions do imply sort permissions
    @attributes_extension = nil # true: always add '_attributes'; false: never add '_attributes'; nil: add '_attributes' when accepts_nested_attributes_for applies to the current association
    # fixed config stuff
    @view_levels = ['short', 'index', 'show']
    @mutability_levels = {
      "create" => [ "create", "both" ],
      "update" => [ "update", "both" ],
      "both" => [ "both" ]
    }
    @modification_paradigms = ['create', 'update', 'both']
    @belongs_to_filtrations = ['scalar', 'array'] # or 'filter' for both
    @add_sort_to_belongs_to_if_filtrations_present = true # woomble womble redundant shmekrundant
    @hash_field_types = ["jsonb", "hstore", "json"]
    @array_field_types = ["array", "file_set"]
    @filter_types = ["scalar", "array", "like", "interval"]
    @order_types = ["sort"]
    unless @strict_order_permissions
      @order_types.concat(@filter_types)
      @filter_types = @order_types
    end
  end

  def extract_scheme
    if options['filename'].ends_with?(".json")
      gputs "Extracting JSON..."
      file = File.read(options['filename'])
      @scheme = JSON.parse(file)
      gputs "  Success!"
    elsif options['filename'].ends_with?(".rb") # MOOSE WARNING: has the possibility to introduce all kinds of garbage (e.g. symbol keys)... should not be used until expand_scheme can fix it all
      gputs "Extracting ruby hash..."
      @scheme = "snoot snoot I'm a fluffy hound, snortin' around, woof woof woof, and I wag my tail oh yeah, snoot snoot!".instance_eval(File.read(options['filename']))
      if @scheme.class == ::String # try to parse it as JSON if we go ta string instead of a native hash
        @scheme = JSON.parse(@scheme) rescue nil
      end
      if @scheme.class != ::Hash
        raise ArgumentError.new("File '#{options['filename']}' does not evaluate to a hash or a JSON string!")
      end
      gputs "  Success!"
    else
      raise ArgumentError.new("Filename '#{options['filename']}' must be a JSON file (.json) or a ruby file (.rb) evaluating to a hash, but is neither!")
    end
  end
  
  def expand_scheme
    gputs "Expanding scheme..."
    # MOOSE WARNING: copy context data to subcontexts...
    # expand shallow associations as fields
    gputs "  Expanding shallow associations..."
    (@scheme['models'] || {}).each do |m_name, m_data|
      custom_partials = m_data['custom_partials'] || []
      perms_list = @view_levels + custom_partials + @modification_paradigms + @belongs_to_filtrations + ['filter', 'sort'] # WARNING: no custom modification paradigm support
      (m_data['associations'] || {}).each do |a_name, a_data|
        if a_data['type'] == 'belongs_to' && a_data['through'].nil?
          permissions = a_data['permissions'].select{|ctx, perms| (perms & perms_list).length > 0 }.transform_values{|perms| (perms & perms_list).map{|p| p == 'filter' ? @belongs_to_filtrations : p }.flatten }
          if @add_sort_to_belongs_to_if_filtrations_present
            permissions.each{|ctx, perms| perms.push('sort') unless (@belongs_to_filtrations & perms).blank? }
          end
          unless permissions.blank?
            foreign_key = extract_foreign_key(a_name, a_data)
            foreign_type = extract_foreign_type(a_name, a_data)
            m_data['fields'] = {} unless m_data.has_key?('fields')
            unless foreign_key.nil? || m_data['fields'].has_key?(foreign_key)
              m_data['fields'][foreign_type] = {
                'type' => 'belongs_to_key',
                'association_name' => a_name,
                'permissions' => Marshal.load(Marshal.dump(permissions))
              }
            end
            unless foreign_type.nil? || m_data['fields'].has_key?(foreign_type)
              m_data['fields'][foreign_type] = {
                'type' => 'belongs_to_type',
                'association_name' => a_name,
                'permissions' => Marshal.load(Marshal.dump(permissions))
              }
            end
          end
        end
      end
    end
    # precalculate viewable contexts
    gputs "  Determining viewable contexts..."
    (@scheme['models'] || {}).each do |m_name, m_data|
      m_data['viewable_contexts'] = get_viewable_contexts(m_data)
    end
  end
  
  def actualize_views
    gputs "Generating views..."
    gputs_in
    (@scheme['models'] || {}).each do |m_name, m_data|
      @m_name = m_name
      @m_data = m_data
      m_data['viewable_contexts'].select{|ctx, views| views.any?{|v| view_actualization_allowed(m_name, ctx, v) } }.each do |ctx, views|
        @ctx = ctx
        @view_path = get_view_path(m_name, ctx)
        @available_views = views
        gputs "Building #{@view_path} views..."
        # build views
        views.each do |view|
          next unless view_actualization_allowed(m_name, ctx, view)
          @view = view
          template "views/fields_partial.json.jbuilder.erb", "app/views/#{@view_path}/#{get_fields_partial_filename(m_name, ctx, view)}", force: should_force_view(m_name, ctx, view)
          template "views/full_partial.json.jbuilder.erb", "app/views/#{@view_path}/#{get_full_partial_filename(m_name, ctx, view)}", force: should_force_view(m_name, ctx, view)
          if @view_levels.include?(view) # MOOSE WARNING: we only build built-in views here, even though we build custom partials as well
            template "views/#{view}.json.jbuilder.erb", "app/views/#{@view_path}/#{vn}.json.jbuilder", force: should_force_view(m_name, ctx, view)
          end
        end
      end
    end
    gputs_out
  end
  
  def actualize_namespace_controllers
  end
  
  def actualize_model_controllers
    gputs "Generating model controllers..."
    gputs_in
    # MOOSE WARNING: precede this by deleting old controllers... maybe. (in case we've removed certain context's access)
    (@scheme['models'] || {}).each do |m_name, m_data|
      @m_name = m_name
      @m_data = m_data
      if m_name == @special_history_model # MOOSE WARNING: implement this
        # build special history controllers
      elsif m_data.has_key?('verbs')
        # build standard model controllers
        m_data['verbs'].select{|ctx, verbs| controller_actualization_allowed(m_name, ctx) }.each do |ctx, verbs|
          @available_views = m_data['viewable_contexts'][ctx] || []
          @ctx = ctx
          @ctx_data = @scheme['contexts'][@ctx] # MOOSE WARNING: right now this shizzle can be nested
          @verbs = verbs
          @controller_path = get_controller_path(m_name, ctx)
          @controller_filename = get_controller_filename(m_name, ctx)
          @full_controller_path = "app/controllers/#{@controller_path}/#{@controller_filename}"
          gputs "Building #{@full_controller_path}"
          template "controller.rb.erb", @full_controller_path, force: should_force_controller(m_name, ctx)
        end
      end
    end
    gputs_out
  end
  
private
  
  # printing tools
  def gputs(text)
    puts "#{@gputs_indentation}#{text}"
  end
  
  def gputs_in
    @gputs_indentation += 1
  end
  
  def gputs_out
    @gputs_indentation -= 1 unless @gputs_indentation == 0
  end
  
  # allowability checkers
  def view_actualization_allowed(m_name, ctx, view)
    # MOOSE WARNING: do this
  end
  
  def controller_actualization_allowed(m_name, ctx)
    # MOOSE WARNING: do this
  end
  
  def should_force_view(m_name, ctx, view)
    @force
  end
  
  def should_force_controller(m_name, ctx)
    @force
  end
  
  # association data extractors
  
  def extract_foreign_key(a_name, a_data)
    return a_data["through"].nil? ? (a_data["foreign_key"] || "#{a_name}_id") : nil
  end
  
  def extract_foreign_type(a_name, a_data)
    return a_data["through"].nil? ? (a_data["foreign_type"] || "#{a_name}_type") : nil
  end
  
  # GENERAL: helpful getters
  
  def get_ctx_folder_name(ctx)
    ctx # MOOSE WARNING: nah man... nest dem roles!
  end
  
  # CONTROLLERS: helpful getters
  
  def get_controller_path(m_name, ctx)
    "v2/#{get_ctx_folder(ctx)}"
  end
  
  def get_controller_filename(m_name, ctx)
    "#{m_name.pluralize.underscore}_controller.rb"
  end
  
  def get_verbs_needing_set(m_data)
    ["show", "update", "destroy"] + (m_data["custom_verbs"] || {}).select{|can,cad| cad["type"] == "member" }.map{|can, cad| cad["to"] }
  end
  
  # VIEWS: helpful getters
  
  def get_view_path(m_name, ctx)
    "v2/#{get_ctx_folder(ctx)}/#{m_name.pluralize.underscore}"
  end
  
  def get_fields_partial_filename(m_name, ctx, view, with_underscore = true)
    "#{with_underscore ? '_' : ''}#{m_name.underscore}_#{view}_fields.json.jbuilder"
  end
  
  def get_full_partial_filename(m_name, ctx, view, with_underscore = true)
    "#{with_underscore ? '_' : ''}#{m_name.underscore}_#{view}_full.json.jbuilder"
  end
  
  def get_partial_filename(m_name, ctx, partial, with_underscore = true)
    "#{with_underscore ? '_' : ''}#{m_name.underscore}_#{@view_levels.include?(partial) ? "#{partial}_full" : partial}.json.jbuilder"
  end

  def get_viewable_contexts(m_data)
    to_return = {}
    custom_views = m_data['custom_partials'] || []
    # add field views
    (m_data['fields'] || {}).each do |f_name, f_data|
      (f_data['permissions'] || {}).each do |ctx, perms|
        views_to_add = (@view_levels + custom_partials) & perms
        unless views_to_add.blank?
          to_return[ctx] = [] unless to_return.has_key?(ctx)
          to_return[ctx].concat(views_to_add).uniq!
        end
      end
    end
    # add association views
    (m_data['associations'] || {}).each do |a_name, a_data|
      (a_data['permissions'] || {}).each do |ctx, perms|
        to_return[ctx] = [] unless to_return.has_key?(ctx)
        to_return[ctx].concat(perms.map{|p| (@view_levels + custom_partials).select{|vl| p == vl || p.starts_with?("#{vl}_") } }.flatten).uniq!
      end
    end
    # add superviews
    (1...@view_levels.length).each do |vli|
      to_return.each do |ctx, views|
        views.push(@view_levels[vli]) if views.include?(@view_levels[vli - 1])
      end
    end
    # clean up
    to_return.each do |ctx, views|
      views.uniq!.sort.sort_by{|v| @view_levels.index(v) || @view_levels.length } # sort with built-in views in order at the beginning, followed by any custom views alphabetically
    end
    to_return.delete_if{|ctx, views| views.blank? }
    # done
    return(to_return)
  end
  
end









































