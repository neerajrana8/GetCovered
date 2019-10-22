require "json"

class FromHashGenerator < Rails::Generators::Base
  desc "This generator produces views, controllers, and routes in accordance with a provided JSON or Ruby hash file."
  class_option :filename, type: :string
  class_option :views, type: :string
  class_option :controllers, type: :string
  class_option :output_root, type: :string
  source_root File.expand_path("../templates", __FILE__)

  def init
    @scheme = {}
    # logging variables
    @errors = []
    @gputs_indentation = 0
    # command-line options & other config stuff
    @output_root = options['output_root'].blank? ? "" : "#{options['output_root'].chomp('/')}/"
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
    @verb_types = ['index', 'show', 'create', 'update', 'destroy']
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
    # expand context data
    (@scheme['contexts'] || {}).each do |ctx, ctx_data|
      ctx_data['module'] = ctx.camelize unless ctx_data.has_key?('module')
      ctx_data['path'] = ctx.underscore unless ctx_data.has_key?('path')
      ctx_data['module_sequence'] = [ ctx_data['module'] ] # routes only support module depth 1 right now, but the controller erb supports arbitrary depth using this field
    end
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
          template "views/fields_partial.json.jbuilder.erb", "#{@output_root}app/views/#{@view_path}/#{get_fields_partial_filename(m_name, ctx, view)}", force: should_force_view(m_name, ctx, view)
          template "views/full_partial.json.jbuilder.erb", "#{@output_root}app/views/#{@view_path}/#{get_full_partial_filename(m_name, ctx, view)}", force: should_force_view(m_name, ctx, view)
          if @view_levels.include?(view) # MOOSE WARNING: we only build built-in views here, even though we build custom partials as well
            template "views/#{view}.json.jbuilder.erb", "#{@output_root}app/views/#{@view_path}/#{vn}.json.jbuilder", force: should_force_view(m_name, ctx, view)
          end
        end
      end
    end
    gputs_out
  end
  
  def actualize_application_controller
    if application_controller_actualization_allowed
      gputs "Generating application controller..."
      copy_file "application_controller.rb", "#{@output_root}app/controllers/application_controller.rb", force: should_force_application_controller
      gputs "  Success!"
    end
  end

  def actualize_v1_controller
    if v1_controller_actualization_allowed
      gputs "Generating v1 controller..."
      copy_file "v1_controller.rb", "#{@output_root}app/controllers/v1_controller.rb", force: should_force_v1_controller
      gputs "  Success!"
    end
  end

  def actualize_context_controllers
    puts "Generating context controllers..."
    (@scheme["contexts"] || {}).select{|ctx, ctx_data| context_controller_actualization_allowed(ctx) }.each do |ctx, ctx_data|
      @ctx = ctx
      @ctx_data = ctx_data
      @full_controller_path = "app/controllers/#{get_context_controller_path(ctx)}/#{get_context_controller_filename(ctx)}_controller.rb"
      template "context_controller.rb.erb", "#{@output_root}#{@full_controller_path}", force: should_force_context_controller(ctx)
    end
    puts "  Success!"
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
          template "controller.rb.erb", "#{@output_root}#{@full_controller_path}", force: should_force_controller(m_name, ctx)
        end
      end
    end
    gputs_out
  end
  
  def actualize_routes
    if route_actualization_allowed
      gputs "Generating routes..."
      gputs_in
      routes_hash = get_routes_hash
      template "routes.rb.erb", "#{@output_root}config/routes.rb", force: should_force_routes
      (@scheme['contexts'] || {}).each do |ctx, ctx_data|
        @ctx = ctx
        @ctx_data = ctx_data
        @r_data = routes_hash[ctx] || {}
        template "context_routes.rb.erb", "#{@output_root}config/routes/#{ctx.underscore}.rb", force: should_force_routes
      end
      gputs_out
    end
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
    true # MOOSE WARNING: do this
  end
  
  def application_controller_actualization_allowed
    true # MOOSE WARNING: do this
  end
  
  def v1_controller_actualization_allowed
    true # MOOSE WARNING: do this
  end
  
  def context_controller_actualization_allowed(ctx)
    true # MOOSE WARNING: do this
  end
  
  def controller_actualization_allowed(m_name, ctx)
    true # MOOSE WARNING: do this
  end
  
  def route_actualization_allowed
    true # MOOSE WARNING: do this
  end
  
  def should_force_view(m_name, ctx, view)
    @force
  end
  
  def should_force_application_controller
    @force
  end
  
  def should_force_v1_controller
    @force
  end
  
  def should_force_context_controller(ctx)
    @force
  end
  
  def should_force_controller(m_name, ctx)
    @force
  end
  
  def should_force_routes
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
  
  def get_ctx_folder(ctx)
    ctx.underscore # MOOSE WARNING: nah man... nest dem roles!
  end
  
  def get_human_readable_context_name(ctx)
    ctx.camelize
  end
  
  # CONTROLLERS: helpful getters
  
  def get_context_controller_name(ctx)
    ctx.camelize
  end
  
  def get_context_controller_path(ctx)
    "v2"
  end
  
  def get_controller_path(m_name, ctx)
    "v2/#{get_ctx_folder(ctx)}"
  end
  
  def get_context_controller_filename(ctx)
    "#{ctx.underscore}_controller.rb"
  end
  
  def get_controller_filename(m_name, ctx)
    "#{m_name.pluralize.underscore}_controller.rb"
  end
  
  def get_verbs_needing_set(m_data)
    ["show", "update", "destroy"] + (m_data["custom_verbs"] || {}).select{|can,cad| cad["type"] == "member" }.map{|can, cad| cad["to"] }
  end
  
  def get_verbs_needing_substrate(m_data)
    ["index", "create"] + (m_data["custom_verbs"] || {}).select{|can,cad| cad["type"] == "collection" }.map{|can, cad| cad["to"] }
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
  
  # ROUTES: helpful getters
  def get_routes_hash
    # format: to_return[context] = { resource: { verbs, path, concerns, block: { member: [ {verb, path, to, as, defaults} ] }, mounted_routes: ##copy of same format## } }
    to_return = {}
    # grab routes
    @scheme['models'].each do |m_name, m_data|
      c_name = m_name.pluralize.underscore
      (m_data["verbs"] || {}).each do |ctx, verbs|
        unless verbs.blank?
          to_return[ctx] = {} unless to_return.has_key?(ctx)
          # built-in verbs
          built_in_verbs = verbs & @verb_types
          to_return[ctx][c_name] = (built_in_verbs.blank? ? {} : { "verbs" => built_in_verbs })
          to_return[ctx][c_name]['path'] = c_name.gsub('_', '-') if c_name.include?('_')
          # custom verbs
          (m_data['custom_verbs' || {}).select{|can, cad| verbs.include?(can) }.each do |v_name, v_data|
            to_return[ctx][c_name]['block'] = {} unless to_return[ctx][c_name].has_key?('block')
            klondike = (case v_data['type']; when 'member'; 'member'; when 'collection'; 'collection'; else; nil; end)
            unless klondike.nil?
              (to_return[ctx][c_name]['block'][klondike] = to_return[ctx][c_name]['block'][klondike] || []).push({
                'verb' => v_data['via'],
                'path' => v_data['path'],
                'to' => "#{m_name.pluralize.underscore}##{v_data['to']}",
                'as' => v_data['as'] || "#{m_name.pluralize.underscore}_#{v_name}"
              })
            end
          end
          # route mounts
          route_mounts = m_name['route_mounts'].select{|rm| !rm.has_key?('contexts') || rm['contexts'] == true || (rm['contexts'].class == ::Array && rm['contexts'].has_key?(ctx)) }
          to_return[ctx]['route_mounts'] = route_mounts unless route_mounts.blank?
          # history
          if (((@scheme["specials"] || {})["history"] || {})["contexts"] || []).include?(ctx) && ((m_data["specials"] || {})["history"] || {})["history_verbs"]
            to_return[ctx][c_name]["block"] = {} unless to_return[ctx][c_name].has_key?("block")
            to_return[ctx][c_name]["block"]["member"] = [] unless to_return[ctx][c_name]["block"].has_key?("member")
            to_return[ctx][c_name]["block"]["member"].push({
              "action" => "get",
              "path" => "histories",
              "to" => "histories#index_recordable",
              "as" => "#{c_name}_histories_index_recordable",
              "defaults" => {
                'recordable_type' => m_name
              }
            })
          end
          if (((@scheme["specials"] || {})["history"] || {})["contexts"] || []).include?(ctx) && ((m_data["specials"] || {})["history"] || {})["author_verbs"]
            to_return[ctx][c_name]["block"]["member"].push({
              "action" => "get",
              "path" => "authored-histories",
              "to" => "histories#index_authorable",
              "as" => "#{c_name}_histories_index_authorable",
              "defaults" => {
                'authorable_type' => m_name
              }
            })
          end
        end
      end
    end
    # check for invalid route mounts & build mount_paths hash
    mount_paths = {}
    to_return.each do |ctx, route_data|
      mount_paths[ctx] = {}
      route_data.each do |resource, data|
        mount_paths[ctx][resource] = {} unless mount_paths[ctx].has_key?(resource) || !data['route_mounts'].blank?
        (data['route_mounts'] || []).each do |rm_data|
          next if rm_data['mount_path'].length == 1 && rm_data['mount_path'][0].nil?
          last = resource
          ([nil] + rm_data['mount_path'].map{|model_name| [mounted_upon, model_name.pluralize.underscore] }.reverse).each do |mounted_upon|
            raise "ERROR: #{resource.singularize.camelize} has route mounted on #{rm_data['mount_path'].join('->')}, but these intermediate mountings do not all exist!" unless route_data.any? do |r,d|
              next false unless d.has_key?(last)
              if mounted_upon.nil?
                next (!d[last].has_key?('route_mounts') || d[last]['route_mounts'].any?{|gurgle| gurgle['mount_path'].length == 1 && gurgle['mount_path'][0].nil? })
              else
                next (d[last].has_key?('route_mounts') && d[last]['route_mounts'].any?{|gurgle| gurgle['mount_path'].last == mounted_upon[0] })
              end
            end
            last = mounted_upon[1] unless mounted_upon.nil?
          end
          # mount_paths time
          cur = mount_paths[ctx]
          rm_data['mount_path'].each do |mp_c|
            next if mp_c.nil?
            mp = mp_c.pluralize.underscore
            cur[mp] = {} unless cur.has_key?(mp)
            cur = cur[mp]
          end
          cur[resource] = {} unless cur.has_key?(mp)
        end
      end
    end
    # fix route mounts
    new_to_return = to_return.map{|ctx,v| [ctx,{}] }.to_h
    construct_stuff = Proc.new do |mount_path_pos, to_return_pos, ctx|
      mount_path_pos.each do |resource, subresource_hash|
        to_return_pos[resource] = Marshal.load(Marshal.dump(to_return[ctx][resource].select{|k,v| k != 'route_mounts'}))
        unless subresource_hash.blank?
          to_return_pos[resource]['block'] = {} unless to_return_pos[resource].has_key?('block')
          to_return_pos[resource]['block']['subroutes'] = {}
          construct_stuff(subresource_hash, to_return_pos[resource]['block']['subroutes'], ctx)
        end
      end
    end
    to_return.keys.each do |ctx|
      new_to_return[ctx] = {}
      construct_stuff.call(mount_paths[ctx], new_to_return[ctx], ctx)
    end
    to_return = new_to_return
    # done
    return(to_return)
  end
  
end









































