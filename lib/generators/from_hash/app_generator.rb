require "json"


class AppGenerator < Rails::Generators::Base
  desc "This generator produces model, controller, view, and rspec files in accordance with a provided JSON application map file."
  class_option :filename, type: :string
  class_option :"except-tests", type: :boolean
  class_option :"except-migrations", type: :boolean

  class_option :"strict-order-permissions", type: :boolean
  class_option :force, type: :boolean
  class_option :"clear-migrations", type: :boolean
  class_option :"old-references", type: :boolean
  class_option :"js-scheme", type: :boolean
  source_root File.expand_path("../templates", __FILE__)

  def init
    # logging variables
    @errors = []
    # command-line options
    @should_generate_tests = options['except-tests'] ? false : true
    @should_generate_migrations = options['except-migrations'] ? false : true
    @strict_order_permissions = options['strict-order-permissions'] ? true : false
    @force = options['force'] ? true : false
    @clear_migration = options['clear-migrations'] ? true : false
    @new_references = options['old-references'] ? true : false
    @js_scheme = options['js-scheme'] ? true : false
    # options bookkeeping
    @restful_actions = ["index", "show", "update", "create", "new", "destroy"]
    @hash_field_types = ["jsonb", "hstore", "json"]
    @array_field_types = ["array", "file_set"]
    @reserved_namespace_names = ["nested"]
    @view_levels = ["short", "index", "show"]
    @join_view_levels = (0...(@view_levels.length * @view_levels.length)).map{ |v| "#{@view_levels[v % @view_levels.length]}_#{@view_levels[ (v / @view_levels.length) % @view_levels.length ]}" }
    @mutability_levels = {
      "create" => [ "create", "mutable" ],
      "update" => [ "update", "mutable" ],
      "mutable" => [ "mutable" ]
    }
    @filter_types = ["scalar", "array", "like", "interval"]
    @order_types = ["sort", "sort_only"]
    unless @strict_order_permissions
      @order_types.concat(@filter_types)
      @filter_types = @order_types
    end
  end

  def extract_file
    puts "Extracting JSON..."
    file = File.read(options['filename'])
    @scheme = JSON.parse(file)
    puts "  Success!"
  end

  def expand_special_data
    if @scheme['specials']
      puts "Expanding special data..."
      if @scheme['specials']['universals']
        puts "  Expanding universals..."
        expand_special_data_for_universals
      end
      if @scheme['specials']['history']
        puts "  Expanding history..."
        expand_special_data_for_history
      end
      puts "  Expanding file downloads..."
      expand_special_data_for_files
      puts "  Success!"
    end
  end

  def perform_default_expansions
    puts "Expanding scheme data..."
    puts "  Expanding multi-fields..."
    expand_multi_fields
    puts "    Success!"
    puts "  Expanding field autoexpansions..."
    perform_field_autoexpansions
    puts "    Success!"
    puts "  Expanding namespace groupings..."
    expand_namespace_groupings
    puts "    Success!"
    puts "  Success!"
  end

  def load_referenced_files
    puts "Loading files referenced by scheme..."
    puts "  Loading test files..."
    (@scheme["models"] || {}).select{|mn,md| md.has_key?("extra_model_tests_from") }.each do |m_name, m_data|
      puts "    Loading tests for #{m_name}..."
      file = File.read(File.join(File.dirname(options['filename']), m_data["extra_model_tests_from"]))
      m_data["extra_model_tests"] = [] unless m_data.has_key?("extra_model_tests")
      m_data["extra_model_tests"].concat(file.split("\n"))
    end
    puts "    Success!"
    puts "  Success!"
  end

  def clear_migrations
    if @clear_migration
      puts "Clearing migrations..."
      FileUtils.rm_rf('db/migrate') if File.directory?('db/migrate')
      FileUtils.rm('db/schema.rb') if File.exist?('db/schema.rb')
      puts "  Success!"
    end
  end

  def g_uploaders
    uploaders = {}
    (@scheme["models"] || {}).each do |m_name, m_data|
      (m_data["fields"] || {}).select{|fn,fd| fd["type"] == "file" || fd["type"] == "file_set"}.each do |f_name, f_data|
        uploaders[m_name] = [] unless uploaders.has_key?(m_name)
        uploaders[m_name].push(f_name)
      end
    end
    unless uploaders.blank?
      puts "Generating file uploaders..."
      uploaders.each do |m_name, fields|
        fields.each do |f_name|
          generate "uploader", "#{m_name}_#{f_name.camelize}" # MOOSE WARNING: force?
        end
      end
      puts "  Success!"
    end
  end

  def g_extension_enabling_migration
    puts "Generating migration to enable database extensions..."
    copy_file "00000000000000_enable_extensions.rb", "db/migrate/00000000000000_enable_extensions.rb", force: @force
    puts "  Success!"
  end

  def g_concerns
    if @scheme["model_concerns_from"]
      puts "Generating concerns..."
      FileUtils.cp_r(Dir.glob(File.join(File.dirname(options['filename']), @scheme["model_concerns_from"], ".")), 'app/models/concerns') # MOOSE WARNING: do we need to force this?
      puts "  Success!"
    end
  end

  def g_models
    sleep_i = 1
    puts "Generating models..."
    puts "  Building ApplicationRecord..."
    copy_file "application_record.rb", "app/models/application_record.rb", force: @force
    models = @scheme["models"] || {}
    models.each do |name, data|
      # generate migration
      if @should_generate_migrations
        unless (@scheme["specials"] || {}).has_key?("devise") && (data["specials"] || []).include?("devise") # exclude these since devise_token_auth insists on creating the table itself
          puts "  Building migration for #{name}..."
          # fields
          fields = extract_fields(data)
          sleep(0.1 * sleep_i)
          sleep_i = sleep_i + 1
          generate "migration", "Create#{name} #{fields.to_a.map{|f| "#{f[0]}:#{f[1]}" }.join(" ")}"
          sleep(0.1 * sleep_i)
          # indices
          matches = Dir.glob("db/migrate/*_create_#{name.underscore}.rb")
          if matches.length != 1
            puts "    ERROR: failed to locate migration file to add indices!"
            @errors.push({ step: "Model Generation >> Migration for #{name}", message: "failed to locate migration file to add indices!" })
          else
            filename = matches[0]
              indices = extract_indices(name, data)
              indices.each do |i_name, i_data|
                to_insert = "add_index :#{name.pluralize.underscore}, #{i_data["columns"].length > 1 ? "[ " : ""}#{i_data["columns"].map{|c| ":#{c}"}.join(", ")}#{i_data["columns"].length > 1 ? " ]" : ""}#{i_data["unique"] ? ", unique: true" : ""}, name: '#{i_name}'"
                gsub_file filename, /\n  end\n/m, "\n    #{to_insert}\n  end\n"
              end          
          end
        end
      end
      # generate model
      @model_name = name
      @model_data = data
      @model_path = "app/models/#{name.underscore}.rb"
      puts "  Building #{name} from template..."
      template "model.rb.erb", @model_path, force: @force
    end
    puts "  Success!"
  end

  def g_views
    puts "Generating views..." # MOOSE WARNING: modify this so that it doesn't create unnecessary views
    (@scheme["models"] || {}).each do |model_name, model_data|
      get_viewable_namespaces(model_data).each do |ns_name, views|
        @ns_name = ns_name
        @model_name = model_name
        @model_data = model_data
        @view_path = "v1/#{@ns_name.underscore}/#{@model_name.pluralize.underscore}"
        puts "  Building v1/#{ns_name}/#{model_name.pluralize.underscore} from templates..."
        views.each do |view_type|
          @view_type = view_type
          template "views/partial.json.jbuilder.erb", "app/views/#{@view_path}/_#{@model_name.underscore}_#{@view_type}.json.jbuilder", force: @force
        end
        (@view_levels & views).each do |view_type|
          vn = (view_type == 'short' ? 'index_short' : view_type)
          template "views/#{vn}.json.jbuilder.erb", "app/views/#{@view_path}/#{vn}.json.jbuilder", force: @force
        end
        (model_data['custom_views'] || {}).each do |view_name, view_data|
          if (view_data['namespaces'] || []).include?(ns_name)
            @custom_view_source = view_data['source'] || ""
            @view_name = view_name
            template "views/custom.json.jbuilder.erb", "app/views/#{@view_path}/#{@view_name}.json.jbuilder", force: @force
          end
        end
      end
    end
    puts "  Success!"
  end

  def g_application_controller
    puts "Generating application controller..."
    copy_file "application_controller.rb", "app/controllers/application_controller.rb", force: @force
    puts "  Success!"
  end

  def g_v1_controller
    puts "Generating v1 controller..."
    copy_file "v1_controller.rb", "app/controllers/v1_controller.rb", force: @force
    puts "  Success!"
  end

  def g_namespace_controllers
    puts "Generating namespace controllers..."
    namespaces = @scheme["namespaces"] || {}
    namespaces.each do |name, data|
      @ns_name = name
      @ns_data = data
      @ns_path = "app/controllers/v1/#{name.underscore}_controller.rb"
      puts "  Building #{name} from template..."
      template "namespace_controller.rb.erb", @ns_path, force: @force
    end
    puts "  Success!"
  end

  def g_controllers
    puts "Generating controllers..."
    (@scheme["models"] || {}).each do |model_name, model_data|
      if model_name == @special_history_model
        (((@scheme["specials"] || {})["history"] || {})["namespaces"] || []).each do |ns_name|
          @model_name = model_name
          @model_data = model_data
          @ns_name = ns_name
          @ns_data = {}
          @ns_actions = {}
          @controller_path = "app/controllers/v1/#{ns_name.underscore}/#{model_name.pluralize.underscore}_controller.rb"
          puts "  Building v1/#{ns_name.underscore}/#{model_name.pluralize.underscore}_controller from template..."
          template "histories_controller.rb.erb", @controller_path, force: @force
        end
      elsif model_data.has_key?("actions")
        model_data["actions"].each do |ns_name, ns_actions|
          @model_name = model_name
          @model_data = model_data
          @ns_name = ns_name
          @ns_data = @scheme["namespaces"][@ns_name]
          @ns_actions = ns_actions
          @controller_path = "app/controllers/v1/#{ns_name.underscore}/#{model_name.pluralize.underscore}_controller.rb"
          puts "  Building v1/#{ns_name.underscore}/#{model_name.pluralize.underscore}_controller from template..."
          unless @model_name == @special_history_model
            template "controller.rb.erb", @controller_path, force: @force
          end
        end
      end
    end
    puts "  Success!"
  end

  def g_devise_controllers
    if (@scheme["specials"] || {}).has_key?("devise")
      puts "Generating devise controllers..."
      (@scheme["models"] || {}).select{|m_name, m_data| m_data.has_key?('specials') && m_data['specials'].include?('devise') }.each do |m_name, m_data|
        @m_name = m_name
        @m_data = m_data
        @ns_name = nil
        if @m_data.has_key?('devise') && @m_data['devise'].has_key?('view_namespace')
          @ns_name = @m_data['devise']['view_namespace']
        else
          selected = (@scheme['namespaces'] || {}).select{|ns_name, ns_data| ns_data['user_type'] == @m_name }
          if selected.length == 1
            @ns_name = selected.keys[0]
          end
        end
        if @ns_name.nil?
          @errors.push({ step: "Devise Controller Generation >> Controllers for #{@m_name}", message: "Model scheme lacked ['devise']['view_namespace'] entry, and model was present in more than one namespace! No devise controllers were generated." })
        else
          unless (@scheme["models"][@m_name]["devise"] || {})["uninvitable"]
            template "devise_controllers/invitations_controller.rb.erb", "app/controllers/devise/#{ @m_name.pluralize.underscore }/invitations_controller.rb", force: @force
          end
          template "devise_controllers/passwords_controller.rb.erb", "app/controllers/devise/#{ @m_name.pluralize.underscore }/passwords_controller.rb", force: @force
          template "devise_controllers/sessions_controller.rb.erb", "app/controllers/devise/#{ @m_name.pluralize.underscore }/sessions_controller.rb", force: @force
          template "devise_controllers/token_validations_controller.rb.erb", "app/controllers/devise/#{ @m_name.pluralize.underscore }/token_validations_controller.rb", force: @force
        end
      end
      puts "  Success!"
    end
  end

  def g_routes
    puts "Generating routes..."
    template "routes.rb.erb", "config/routes.rb", force: @force
    puts "  Success!"
  end

  def g_devise
    if (@scheme["specials"] || {}).has_key?("devise")
      sleep_i = 1 # sleep duration variable to keep generators from making migrations with the same version number
      # devise
      puts "Integrating devise..."
      generate "devise:install", (@force ? "--force" : "")
      gsub_file "config/initializers/devise.rb", /# config.secret_key = /, "config.secret_key = "
      # devise_token_auth
      devise_token_auth_installed_for = []
      @scheme["namespaces"].each do |ns_name, ns_data|
        puts "  Setting up devise_token_auth for namespace #{ns_name}..."
        m_name = ns_data["user_type"]
        unless m_name.nil?
          sleep(0.1 * sleep_i)
          sleep_i = sleep_i + 1
          unless devise_token_auth_installed_for.include?(ns_data["user_type"]) # MOOSE WARNING: generates migrations no matter what... we need to disable this if @should_generate_migrations == false...
            generate "devise_token_auth:install", "#{ns_data["user_type"]} v1/auth"
            devise_token_auth_installed_for.push(ns_data["user_type"])
          end
          sleep(0.1 * sleep_i)
          # replace "##User Info" section of migration
          m_data = @scheme["models"][m_name]
          matches = Dir.glob("db/migrate/*_devise_token_auth_create_#{m_name.pluralize.underscore}.rb")
          if matches.length != 1
            puts "    ERROR: devise_token_auth failed to create migration for #{m_name}!"
            @errors.push({ step: "Devise Integration >> Migration for #{m_name}", message: "devise_token_auth failed to create migration for #{m_name}!" })
          else
            filename = matches[0]
            # fields
            fields = extract_fields(m_data).merge({ "email" => "string" })
            gsub_file filename, /## User Info(.*?)\n\n/m, "## User Info\n#{fields.map{|f| "      t.#{f[1]} :#{f[0]}"}.join("\n")}\n\n"
            # indices
            indices = extract_indices(m_name, m_data)
            indices.each do |i_name, i_data|
              to_insert = "add_index :#{m_name.pluralize.underscore}, #{i_data["columns"].length > 1 ? "[ " : ""}#{i_data["columns"].map{|c| ":#{c}"}.join(", ")}#{i_data["columns"].length > 1 ? " ]" : ""}#{i_data["unique"] ? ", unique: true" : ""}, name: '#{i_name}'"
              gsub_file filename, /\n  end\n/m, "\n    #{to_insert}\n  end\n"
            end
          end
        end
      end
      # devise_invitable
      generate "devise_invitable:install"
      devise_invitable_installed_for = []
      @scheme["namespaces"].each do |ns_name, ns_data|
        unless devise_invitable_installed_for.include?(ns_data["user_type"])
          generate "devise_invitable", "#{ns_data["user_type"]}" # MOOSE WARNING: generates migrations no matter what... we need to disable this if @should_generate_migrations == false...
          devise_invitable_installed_for.push(ns_data["user_type"])
        end
      end
      # config files
      gsub_file "config/initializers/devise.rb", /config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'/, "config.mailer_sender = '#{@scheme["specials"]["devise"]["mailer_sender"]}'" if @scheme["specials"]["devise"].has_key?("mailer_sender")
      gsub_file "config/initializers/devise.rb", /# config.validate_on_invite = true/, "config.validate_on_invite = true"
      gsub_file "config/initializers/devise.rb", /# config.scoped_views = false/, "config.scoped_views = true"
      # done
      puts "  Success!"
    end
  end

  def g_environments
    # MOOSE WARNING: you need to configure config/environments yourself...
  end

  def g_factories
    if @should_generate_tests
      puts "Generating factories..."
      @scheme["models"].each do |m_name, m_data|
        @m_name = m_name
        @m_data = m_data
        template "factory.rb.erb", "spec/factories/#{@m_name.pluralize.underscore}.rb", force: @force
      end
      puts "  Success!"
    end
  end

  def g_makers
    if @should_generate_tests
      puts "Generating makers..."
      copy_file "makers/maker.rb", "spec/makers/maker.rb", force: @force
      @scheme["models"].each do |m_name, m_data|
        @m_name = m_name
        @m_data = m_data
        begin
          template "makers/model_maker.rb.erb", "spec/makers/#{m_name.underscore}_maker.rb", force: @force
        rescue RuntimeError => e
          puts "  ERROR: #{e.message}"
          @errors.push({
            step: "Maker Generation >> spec/makers/#{m_name.underscore}_maker",
            message: "#{e.message}"
          })
        end
      end
      puts "  Success!"
    end
  end

  def g_model_specs
    if @should_generate_tests
      puts "Generating model tests..."
      @scheme["models"].each do |m_name, m_data|
        @m_name = m_name
        @m_data = m_data
        template "specs/model_spec.rb.erb", "spec/models/#{m_name.underscore}_spec.rb", force: @force
      end
      puts "  Success!"
    end
  end

  def g_controller_specs
    if @should_generate_tests
      puts "Generating controller tests..."
      copy_file "specs/controller_spec_helper.rb", "spec/helpers/controller_spec_helper.rb", force: @force
      @scheme["models"].each do |m_name, m_data|
        if m_data.has_key?("actions")
          m_data["actions"].each do |ns_name, ns_actions|
            @m_name = m_name
            @m_data = m_data
            @ns_name = ns_name
            @ns_data = @scheme["namespaces"][@ns_name]
            @ns_actions = ns_actions
            begin
              template "specs/controller_spec.rb.erb", "spec/controllers/v1/#{ns_name.underscore}/#{m_name.pluralize.underscore}_controller_spec.rb", force: @force
            rescue RuntimeError => e
              puts "  ERROR: #{e.message}"
              @errors.push({
                step: "Controller Spec Generation >> v1/#{ns_name.underscore}/#{m_name.pluralize.underscore}",
                message: "#{e.message}"
              })
            end
          end
        end
      end
      puts "  Success!"
    end
  end

  def create_js_scheme
    if @js_scheme
      ts_equivalent_of = lambda do |apitype|
        case apitype
          when "boolean"
            return("boolean")
          when "date"
            return("Date")
          when "datetime", "time", "timestamp"
            return("Datetime")
          when "decimal", "float", "integer", "bigint", "primary_key", "references"
            return("number")
          when "string", "text"
            return("string")
          when "hstore", "json", "jsonb"
            return("any")
          when "array"
            return("Array<any>")
          when "binary", "cidr_address", "ip_address", "mac_address"
            return("string")
          when "enum"
            return("string")
          when "file"
            return("any")
          when "file_set"
            return("any")
        end
        return("#{apitype}Model") if apitype == "History" || @scheme["models"].has_key?(apitype)
        return("any")
      end
      # CREATE DASHBOARD MODEL SCHEME
      dash = {}
      @scheme['models'].each do |m_name, m_data|
        next if m_data['no_angular']
        # create
        dash[m_name] = {
          "includes" => [],
          "service_model_includes" => [],
          "enums" => {},
          "type_key" => {},
          "mutable_fields" => {},
          "immutable_fields" => {},
          "actions" => {}
        }
        (m_data["fields"] || {}).each do |f_name, f_data|
          next if f_data["no_angular"]
          if (f_data["permissions"] || {}).select {|ns_name, p_data| (p_data & ["mutable", "create", "update"]).length > 0 }.length > 0
            dash[m_name]["mutable_fields"][f_name] = f_data["angular_type"] || ts_equivalent_of.call(f_data["type"])
          else
            dash[m_name]["immutable_fields"][f_name] = f_data["angular_type"] || ts_equivalent_of.call(f_data["type"])
          end
          # enums
          if f_data["type"] == "enum"
            dash[m_name]["enums"][f_name] = ((f_data["enum"] || {})["values"] || []).map{|v| [v,v.titleize] }
            if f_data.has_key?("enum")
              dash[m_name]["enums"][f_name] = dash[m_name]["enums"][f_name].each{|v| v[1] = f_data["enum"]["humanizations"][v[0]] || v[1] } if f_data["enum"].has_key?("humanizations")
            end
            dash[m_name]["enums"][f_name] = dash[m_name]["enums"][f_name].to_h
          end
        end
        (m_data["relationships"] || {}).each do |r_name, r_data|
          next if r_data['no_angular']
          if r_data["type"] == "has_many"
            if r_data["include_in_angular"] || (r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & (@view_levels | @join_view_levels)).length > 0 }.length > 0
              rel_model = extract_model_name_from_relationship(r_name, r_data)
              next if (@scheme['models'][rel_model] || {})['no_angular']
              dest = ((r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & ["create_nested", "update_nested", "mutable_nested"]).length > 0 }.length > 0) ? dash[m_name]["mutable_fields"] : dash[m_name]["immutable_fields"]
              dest[r_name] = "Array<#{ts_equivalent_of.call(rel_model)}>"
              dash[m_name]["includes"].push(rel_model) unless dash[m_name]["includes"].include?(rel_model) || rel_model == m_name
            end
          elsif r_data["type"] == "has_one"
            if r_data["include_in_angular"] || (r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & (@view_levels | @join_view_levels | ["create_nested", "update_nested", "mutable_nested"])).length > 0 }.length > 0
              rel_model = extract_model_name_from_relationship(r_name, r_data)
              next if (@scheme['models'][rel_model] || {})['no_angular']
              dest = ((r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & ["create_nested", "update_nested", "mutable_nested"]).length > 0 }.length > 0) ? dash[m_name]["mutable_fields"] : dash[m_name]["immutable_fields"]
              dest[r_name] = "#{ts_equivalent_of.call(rel_model)}"
              dash[m_name]["includes"].push(rel_model) unless dash[m_name]["includes"].include?(rel_model) || rel_model == m_name
            end
          elsif r_data["type"] == "belongs_to"
            if r_data["include_in_angular"] || (r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & (@view_levels | ["mutable", "create", "update"])).length > 0 }.length > 0
              dest = (r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & ["mutable", "create", "update"]).length > 0 }.length > 0 ? dash[m_name]["mutable_fields"] : dash[m_name]["immutable_fields"]
              dest[extract_foreign_key(r_name, r_data)] = "number"
              dest[extract_type_key(r_name, r_data)] = "string" if (r_data["belongs_to"] || {})["polymorphic"]
            end
            if r_data["include_in_angular"] || (r_data["permissions"] || {}).select{|ns_name, p_data| (p_data & @join_view_levels).length > 0 }.length > 0
              if (r_data["belongs_to"] || {})["polymorphic"]
                if r_data["belongs_to"]["possible_models"]
                  dash[m_name]["immutable_fields"][r_name] = r_data["belongs_to"]["possible_models"].map{|pm| ts_equivalent_of.call(pm.camelize) }.join("|")
                  dash[m_name]["type_key"][r_name] = extract_type_key(r_name, r_data)
                  r_data["belongs_to"]["possible_models"].each{|pm| dash[m_name]["includes"].push(pm.camelize) unless dash[m_name]["includes"].include?(pm.camelize) || pm.camelize == m_name }
                else
                  dash[m_name]["immutable_fields"][r_name] = "any"
                end
              else
                rel_model = extract_model_name_from_relationship(r_name, r_data)
                next if (@scheme['models'][rel_model] || {})['no_angular']
                dash[m_name]["immutable_fields"][r_name] = "#{ts_equivalent_of.call(rel_model)}"
                dash[m_name]["includes"].push(rel_model) unless dash[m_name]["includes"].include?(rel_model) || rel_model == m_name
              end
            end
          end
        end
        # create standard actions
        # USABLE CONSTANTS:
        #   $model : class - the class of the dashboard-side model corresponding to the api-side model m_name (e.g. CommunityModel for Community)
        #   $urlparams : function(any->any) - method which converts a hash into url parameter format
        #   $dateoutproc : function(Date->string) - method which converts a js Date object to a date string
        #   $datetimeoutproc : function(Date->string) - method which converts a js Date object to a datetime string
        actions = dash[m_name]["actions"]
        if (m_data["actions"] || {}).select{|ns_name, a_data| a_data.include?("index") }.length > 0
          actions["index"] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?("index") }.to_a.map{|v| v[0] },
            "method" => "get",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}",
            "payload" => "{ search: $urlparams({ filter: filter, sort: sort, pagination: pagination }) }",
            "parameters" => [
              { "name" => "filter", "type" => "any", "default" => "{}" },
              { "name" => "sort", "type" => "any", "default" => "{}" },
              { "name" => "pagination", "type" => "any", "default" => "{}" }
            ],
            "returns" => {
              "type" => "Array<$model>",
              "constructor" => "results => JSON.parse(results).map(hash => new $model(hash))"
            }
          }
          actions["short"] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?("index") }.to_a.map{|v| v[0] },
            "method" => "get",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}",
            "payload" => "{ search: $urlparams({ filter: filter, sort: sort, short: true }) }",
            "parameters" => [
              { "name" => "filter", "type" => "any", "default" => "{}" },
              { "name" => "sort", "type" => "any", "default" => "{}" }
            ],
            "returns" => {
              "type" => "Array<$model>",
              "constructor" => "results => JSON.parse(results).map(hash => new $model(hash))"
            }
          }
        end
        if (m_data["actions"] || {}).select{|ns_name, a_data| a_data.include?("show") }.length > 0
          actions["show"] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?("show") }.to_a.map{|v| v[0] },
            "method" => "get",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}/:id",
            "parameters" => [
              { "name" => "id", "type" => "number" }
            ],
            "returns" => {
              "type" => "$model | null",
              "constructor" => "results => new $model(results)"
            }
          }
        end
        if (m_data["actions"] || {}).select{|ns_name, a_data| a_data.include?("create") }.length > 0
          actions["create"] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?("create") }.to_a.map{|v| v[0] },
            "method" => "post",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}",
            "payload" => "Object.assign({ #{m_name.underscore}: #{m_name.underscore}.preserialize() }, extraParams)",
            "parameters" => [
              { "name" => "#{m_name.underscore}", "type" => "$model" },
              { "name" => "extraParams", "type" => "any", "default" => "{}" }
            ],
            "returns" => {
              "type" => "$model | null",
              "constructor" => "results => new $model(results)"
            }
          }
        end
        if (m_data["actions"] || {}).select{|ns_name, a_data| a_data.include?("update") }.length > 0
          actions["update"] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?("update") }.to_a.map{|v| v[0] },
            "method" => "put",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}/:#{m_name.underscore}.id",
            "payload" => "Object.assign({ #{m_name.underscore}: #{m_name.underscore}.preserialize() }, extraParams)",
            "parameters" => [
              { "name" => "#{m_name.underscore}", "type" => "$model" },
              { "name" => "extraParams", "type" => "any", "default" => "{}" }
            ],
            "returns" => {
              "type" => "$model | null",
              "constructor" => "results => new $model(results)"
            }
          }
        end
        if (m_data["actions"] || {}).select{|ns_name, a_data| a_data.include?("destroy") }.length > 0
          actions["destroy"] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?("destroy") }.to_a.map{|v| v[0] },
            "method" => "delete",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}/:id",
            "parameters" => [
              { "name" => "id", "type" => "number" }
            ],
            "returns" => {
              "type" => "any",
              "constructor" => "results => JSON.parse(results)"
            }
          }
        end
        # create custom actions
        (m_data["custom_actions"] || {}).each do |caction_name, caction_data|
          # attempt to derive parameters
          derived_params = caction_data["path"].split("/").select{|ps| ps[0,1] == ":" }.map{|ps| ps[1..-1] }
          id_param_str = ""
          if caction_data["type"] == "member"
            id_param_str = ":id/"
            derived_params = ["id"] + derived_params
          end
          derived_params.map!{|dp| { "name" => dp, "type" => (dp.chomp("id") != dp ? "number" : "any") } }
          derived_params.concat(caction_data["js_parameters"]) if caction_data["js_parameters"]
          # fill actions hash
          actions[caction_name] = {
            "namespaces" => m_data["actions"].select{|ns_name, a_data| a_data.include?(caction_name) }.to_a.map{|v| v[0] },
            "method" => caction_data["via"],
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}/#{id_param_str}#{caction_data["path"]}",
            "payload" => caction_data["js_payload"] ? caction_data["js_payload"] : "{}",
            "parameters" => derived_params,
            "returns" => {
              "type" => caction_data["js_return_type"] || "any",
              "constructor" => caction_data["js_constructor"] || "results => JSON.parse(results)"
            }
          }
          if caction_name == "download" && (m_data["specials"] || []).include?("file") && (m_data["file"] || {}).has_key?("field") && (m_data["file"] || {})["downloadable"]
            actions[caction_name]["special"] = "download"
            actions[caction_name]["payload"] = "{ responseType: ResponseContentType.Blob }"
          end
          # grab extra model includes
          dash[m_name]["service_model_includes"].concat(caction_data["js_model_includes"]) if caction_data["js_model_includes"]
        end
        dash[m_name]["service_model_includes"].uniq!
        # create history actions
        if (@scheme["specials"] || {}).has_key?("history") && (m_data["specials"] || []).include?("history") && (!m_data.has_key?("history") || !m_data["history"]["related_only"])
          dash[m_name]["includes"].push("History")
          actions["history"] = {
            "namespaces" => actions.to_a.map{|a| a[1]["namespaces"] }.flatten.uniq,
            "method" => "get",
            "path" => "#{m_name.pluralize.underscore.gsub("_", "-")}/:id/histories",
            "payload" => "{ search: $urlparams({ filter: { created_at: { start: $datetimeoutproc(start_date), end: $datetimeoutproc(end_date) } } }) }",
            "parameters" => [
              { "name" => "id", "type" => "number" },
              { "name" => "start_date", "type" => "Date" },
              { "name" => "end_date", "type" => "Date" }
            ],
            "returns" => {
              "type" => "Array<HistoryModel>",
              "constructor" => "results => JSON.parse(results).map(hash => new HistoryModel(hash))"
            }
          }
        end
      end
      # CREATE DASHBOARD NAVIGATION SCHEME
      # SAVE DASHBOARD SCHEME
      File.open("js_scheme.json", "w") do |f|
        f.write(JSON.pretty_generate({
          "models" => dash,
          "user_types" => @scheme["namespaces"].to_a.map{|ns| ns[1]["user_type"] }.compact.uniq,
          "namespaces" => @scheme["namespaces"].to_a.each{|ns| ns[1] = ns[1]["user_type"] }.to_h,
          "languages" => { "English" => "en" }
        }.deep_merge(@scheme["angular"] || {})))
      end
    end
  end

  def output_errors
    puts "App generation complete!"
    unless @errors.blank?
      puts "Errors encountered:"
      @errors.each {|e| puts "#{e[:step]} >>: #{e[:message]}" }
    end
  end

  private

    def extract_model_name_from_relationship(rname, rdata)
      return(rdata[rdata["type"]]["class_name"]) if rdata.has_key?(rdata["type"]) && rdata[rdata["type"]].has_key?("class_name")
      return rname.camelize.singularize
    end

    def extract_foreign_key(rname, rdata)
      return rdata["belongs_to"]["foreign_key"] if (rdata["belongs_to"] || {}).has_key?("foreign_key")
      return "#{rname}_id"
    end

    def extract_type_key(rname, rdata)
      return rdata["belongs_to"]["foreign_type"] if (rdata["belongs_to"] || {}).has_key?("foreign_type")
      return "#{rname}_type"
    end

    def get_creation_substrate(rels)
      to_return = nil
      rels.each do |r_name, r_data|
        return(extract_model_name_from_relationship(r_name, r_data)) if r_data["creation_substrate"]
        to_return = get_creation_substrate(r_data["wherethrough"]) unless r_data["wherethrough"].blank?
        return(to_return) unless to_return.nil?
      end
      return(to_return)
    end

    def get_viewable_namespaces(model_data)
      to_return = {}
      custom_view_levels = (model_data['custom_partials'] || []).map{|cv| @view_levels.map{|vl| "#{vl}_#{cv}" } + [cv] }.flatten
      # add vield views
      model_data["fields"].each do |fname, fdata|
        permissions = fdata["permissions"] || {}
        permissions.each do |ns_name, ns_data|
          unless @reserved_namespace_names.include?(ns_name)
            views_to_add = (@view_levels + @join_view_levels + custom_view_levels) & ns_data
            unless views_to_add.blank?
              @view_levels.each{|vl| views_to_add.map!{|vta| !vta.starts_with?("#{vl}_") ? vta : vl } }
              to_return[ns_name] = [] unless to_return.has_key?(ns_name)
              to_return[ns_name].concat(views_to_add).uniq!
            end
          end
        end
      end
      # add relationship views
      (model_data["relationships"] || {}).each do |rname, rdata| # MOOSE WARNING: drill into wherethroughs?
        permissions = rdata["permissions"] || {}
        permissions.each do |ns_name, ns_data|
          unless @reserved_namespace_names.include?(ns_name)
            views_to_add = (@view_levels + @join_view_levels + custom_view_levels) & ns_data
            unless views_to_add.blank?
              @view_levels.each{|vl| views_to_add.map!{|vta| !vta.starts_with?("#{vl}_") ? vta : vl } }
              to_return[ns_name] = [] unless to_return.has_key?(ns_name)
              to_return[ns_name].concat(views_to_add).uniq!
            end
          end
        end
      end
      # add any standard view levels which are supersets of an included view level
      to_return.each do |ns_name, views|
        min_view = @view_levels.length
        (0...(@view_levels.length-1)).each do |vli|
          min_view = vli if vli < min_view && views.include?(@view_levels[vli])
        end
        ((min_view+1)...(@view_levels.length)).each do |vli|
          views.push(@view_levels[vli]) unless views.include?(@view_levels[vli])
        end
      end
      return(to_return)
    end

    def extract_fields(model_data)
      to_return = {}
      (model_data["fields"] || {}).each do |name, data|
        unless data["autogenerated"]
          case data["type"]
            when "enum"
              to_return[name] = "integer"
            when "array"
              to_return[name] = "json"
            when "file"
              to_return[name] = "string"
            when "file_set"
              to_return[name] = "json" # MOOSE WARNING: not jsonb?
            else
              to_return[name] = data["type"]
          end
        end
      end
      (model_data["relationships"] || {}).each do |name, data|
        if data["type"] == "belongs_to" && !data["autogenerated"]
          if !@new_references || (data["belongs_to"] || {})["no_index"] #MOOSE WARNING: using new references will always create an index, so revert to old if no index
            to_return[extract_foreign_key(name, data)] = "bigint"
            to_return[extract_type_key(name, data)] = "string" if data.has_key?("belongs_to") && data["belongs_to"]["polymorphic"]
          else
            to_return["#{name}"] = "references"
            to_return["#{name}"] += "\\{polymorphic\\}" if data.has_key?("belongs_to") && data["belongs_to"]["polymorphic"]
          end
        end
      end
      return(to_return)
    end

    def extract_indices(model_name, model_data)
      to_return = {}
      # extract from indices
      to_return.merge!(model_data["indices"] || {})
      # WARNING: we don't add an email index for devise models because devise_token_auth adds it for us
      # extract from relationships
      (model_data["relationships"] || {}).each do |name, data|
        if data["type"] == "belongs_to" && !data["autogenerated"]
          if !@new_references && !(data["belongs_to"] || {})["no_index"]
            index_name = (data.has_key?("belongs_to") && data["belongs_to"]["index_name"]) ? data["belongs_to"]["index_name"] : "#{model_name.underscore}_references_#{name}"
            to_return[index_name] = {
              "columns" => [ extract_foreign_key(name, data) ]
            }
            to_return[index_name]["columns"].unshift(extract_type_key(name, data)) if data.has_key?("belongs_to") && data["belongs_to"]["polymorphic"]
            to_return[index_name]["unique"] = true if data.has_key?("belongs_to") && data["belongs_to"]["unique_index"]
          end
        end
      end
      return(to_return)
    end

    def expand_special_data_for_history
      @special_history_model = @scheme['specials']['history']['model'] || nil
      @special_history_concern = @scheme['specials']['history']['concern'] || nil
      # MOOSE WARNING: paths and owner_paths should be removed or should be used in histories_controller
      @special_history_paths = {}
      @special_history_owner_paths = {}
      (@scheme["models"] || {}).each do |model_name, model_data|
        if model_data.has_key?("specials") && model_data["specials"].include?("history")
          # add concern
          if (model_data["history"] || {})["related_only"]
            # MOOSE WARNING: the following do not preserve the model/id-being-attached-to-the-other-side-of-the-join-table setup
            if model_data["history"].has_key?("related_create_message")
              model_data["after_commit"] = {} unless model_data.has_key?("after_commit")
              model_data["after_commit"]["record_creation_on_related_histories"] = {
                "on" => "create",
                "source" => [
                  "(related_classes_through || {}).each do |related|",
                  "  self.send(related).histories.create({",
                  "    data: related_create_hash(related),",
                  "    action: 'create_related'",
                  "  }) unless self.send(related).nil?",
                  "end"
                ]
              }
            end
            if model_data["history"].has_key?("related_create_message")
              model_data["before_destroy"] = {} unless model_data.has_key?("before_destroy")
              model_data["before_destroy"]["record_destruction_on_related_histories"] = {
                "source" => [
                  "(related_classes_through || {}).each do |related|",
                  "  self.send(related).histories.create({",
                  "    data: related_destroy_hash(related),",
                  "    action: 'create_related'",
                  "  }) unless self.send(related).nil?",
                  "end"
                ]
              }
            end
          else
            model_data["concerns"] = [] unless model_data.has_key?("concerns")
            model_data["concerns"].push(@special_history_concern) unless @special_history_concern.nil? || model_data["concerns"].include?(@special_history_concern)
          end
          # add special history paths & owner paths
          if model_data.has_key?("actions")
            model_data["actions"].each do |ns_name, ns_actions|
              @special_history_paths[ns_name] = [] if @special_history_paths[ns_name].nil?
              to_push = model_name.pluralize.underscore.gsub("_", "-") # MOOSE WARNING: fancify this once routing support gets more complex
              @special_history_paths[ns_name].push(to_push)
              @special_history_owner_paths[ns_name] = to_push if @scheme["namespaces"] && @scheme["namespaces"][ns_name] && @scheme["namespaces"][ns_name]["user_type"] && @scheme["namespaces"][ns_name]["owner_through"] && model_name == (@scheme["namespaces"][ns_name]["owner_through"] == "self" ? @scheme["namespaces"][ns_name]["user_type"] : extract_model_name_from_relationship( @scheme["namespaces"][ns_name]["owner_through"], @scheme["models"][@scheme["namespaces"][ns_name]["user_type"]]["relationships"][@scheme["namespaces"][ns_name]["owner_through"]]) )
            end
          end
          # make sure model has relationships
          model_data["relationships"] = {} unless model_data.has_key?("relationships")
          # add related classes data
          hrc = get_historically_related_classes_from_relationships(model_data["relationships"] || {}) # lock her up
          ((model_data["history"] || {})["related_creates"] || {}).each do |rname, rcdata|
            hrc.push(rname) unless hrc.include?(rname)
          end
          ((model_data["history"] || {})["related_destroys"] || {}).each do |rname, rddata|
            hrc.push(rname) unless hrc.include?(rname)
          end
          unless hrc.blank?
            model_data["history"] = {} unless model_data.has_key?("history")
            model_data["history"]["related_classes"] = hrc
          end
          # add history relationships
          model_data["relationships"]["histories"] = {
            "type" => "has_many",
            "has_many" => {
              "as" => "recordable",
              "class_name" => "History",
              "foreign_key" => "recordable_id"
            }
          }
          if model_data["specials"].include?("devise")
            model_data["relationships"]["authored_histories"] = {
              "type" => "has_many",
              "has_many" => {
                "as" => "authorable",
                "class_name" => "History",
                "foreign_key" => "authorable_id"
              }
            }        
          end
        end
      end
      @special_history_paths.each { |ns_name, model_names| @special_history_paths[ns_name].uniq! }
    end

    def get_historically_related_classes_from_relationships(relationships)
      to_return = []
      relationships.each do |rname, rdata|
        if rdata["historically_related"]
          to_return.push(rname)
        end
        to_return.concat(get_historically_related_classes_from_relationships(rdata["wherethrough"])) if rdata.has_key?("wherethrough")
      end
      return(to_return)
    end

    def get_routes_hash
      # format: to_return[namespace] = { resource: { actions, path, concerns, block: { member: [ {action, path, to, as, defaults} ] } } }
      to_return = {}
      # grab routes
      @scheme["models"].each do |m_name, m_data|
        c_name = m_name.pluralize.underscore
        (m_data["actions"] || {}).each do |ns_name, a_data|
          unless a_data.blank? # MOOSE WARNING: put other conditions here so that we can override routing of actions; also implement custom paths & concerns here
            to_return[ns_name] = {} unless to_return.has_key?(ns_name)
            filtered_a_data = a_data & @restful_actions
            if filtered_a_data.blank?
              to_return[ns_name][c_name] = {}
            else
              to_return[ns_name][c_name] = { "actions" => filtered_a_data }
            end
            to_return[ns_name][c_name]["path"] = c_name.gsub("_", "-") if c_name.include?('_')
            # custom actions
            (m_data["custom_actions"] || {}).select{|can, cad| a_data.include?(can) }.each do |caction_name, caction_data|
              to_return[ns_name][c_name]["block"] = {} unless to_return[ns_name][c_name].has_key?("block")
              if caction_data["type"] == "member"
                to_return[ns_name][c_name]["block"]["member"] = [] unless to_return[ns_name][c_name]["block"].has_key?("member")
                caction_hash = {}
                caction_hash["action"] = caction_data["via"]
                caction_hash["path"] = caction_data["path"]
                caction_hash["to"] = "#{m_name.pluralize.underscore}##{caction_data["to"]}"
                caction_hash["as"] = caction_data["as"] || "#{m_name.pluralize.underscore}_#{caction_name}"
                to_return[ns_name][c_name]["block"]["member"].push(caction_hash)
              elsif caction_data["type"] == "collection"
                to_return[ns_name][c_name]["block"]["collection"] = [] unless to_return[ns_name][c_name]["block"].has_key?("collection")
                caction_hash = {}
                caction_hash["action"] = caction_data["via"]
                caction_hash["path"] = caction_data["path"]
                caction_hash["to"] = "#{m_name.pluralize.underscore}##{caction_data["to"]}"
                caction_hash["as"] = caction_data["as"] || "#{m_name.pluralize.underscore}_#{caction_name}"
                to_return[ns_name][c_name]["block"]["collection"].push(caction_hash)
              end
            end
            # history
            if (((@scheme["specials"] || {})["history"] || {})["namespaces"] || []).include?(ns_name) && (m_data["specials"] || []).include?("history") && (!m_data.has_key?("history") || !m_data["history"]["related_only"])
              to_return[ns_name][c_name]["block"] = {} unless to_return[ns_name][c_name].has_key?("block")
              to_return[ns_name][c_name]["block"]["member"] = [] unless to_return[ns_name][c_name]["block"].has_key?("member")
              to_return[ns_name][c_name]["block"]["member"].push({
                "action" => "get",
                "path" => "histories",
                "to" => "histories#index_recordable",
                "as" => "#{c_name}_histories_index_recordable",
                "defaults" => {
                  recordable_type: m_name
                }
              })
            end
            if (((@scheme["specials"] || {})["history"] || {})["namespaces"] || []).include?(ns_name) && (m_data["specials"] || []).include?("history") && (m_data["relationships"] || {}).has_key?("authored_histories")
              to_return[ns_name][c_name]["block"]["member"].push({
                "action" => "get",
                "path" => "authored-histories",
                "to" => "histories#index_authorable",
                "as" => "#{c_name}_histories_index_authorable",
                "defaults" => {
                  authorable_type: m_name
                }
              })
            end
          end
        end
      end
      # done
      return(to_return)
    end

    def expand_special_data_for_files
      (@scheme["models"] || {}).each do |m_name, m_data|
        if (m_data["specials"] || []).include?("file") && (m_data["file"] || {}).has_key?("field")
          # add empty tracking
          if ((@scheme["specials"] || {})["file"] || {})["empty_check_on_file_models"] || (m_data.has_key?("file") && m_data["file"]["empty_check"])
            m_data["file"]["empty_check"] = true
            m_data["fields"] = {} unless m_data.has_key?("fields")
            m_data["fields"]["files_are_null"] = {
              "type" => "boolean",
              "default" => "true"
            }
            m_data["fields"]["files_nullified_at"] = {
              "type" => "datetime",
              "default" => "Time.current"
            }
            m_data["fields"]["preserve_if_nullified"] = {
              "type" => "boolean",
              "default" => ((@scheme["specials"] || {})["file"] || {})["preserve_if_nullified"] ? "true" : "false"
            }
            m_data["indices"] = {} unless m_data.has_key?("indices")
            m_data["indices"]["#{m_name.underscore}_file_is_null_index"] = {
              "columns" => [ "files_are_null", "files_nullified_at", "preserve_if_nullified" ]
            }
          end
          # add download actions
          if (m_data["file"] || {})["downloadable"]
            downloaders = []
            (m_data["actions"] || {}).each do |ns_name, a_data|
              downloaders.push(ns_name) if a_data.include?("download")
            end
            if downloaders.blank?
              (m_data["actions"] || {}).each do |ns_name, a_data|
                downloaders.push(ns_name) if a_data.include?("show")
              end
            end
            downloaders.each{|dldr| m_data["actions"][dldr].push("download") }
            unless downloaders.blank?
              m_data["custom_actions"] = {} unless m_data.has_key?("custom_actions")
              m_data["custom_actions"]["download"] = {
                "type" => "member",
                "path" => "download",
                "via" => "get",
                "to" => "download"
              } unless m_data["custom_actions"].has_key?("download")
              m_data["controller_public_methods"] = {} unless m_data.has_key?("controller_public_methods")
              m_data["controller_public_methods"]["download"] = {
                "namespaces" => downloaders,
                "source" => [
                  "if @#{m_name.underscore}.#{m_data["file"]["field"]}.nil?",
                  "  render json: { 'Error' => 'File does not exist.' },",
                  "    status: :unprocessable_entity",
                  "else",
                  "  data = open(@#{m_name.underscore}.#{m_data["file"]["field"]}.url)",
                  "  send_data data.read, filename: @#{m_name.underscore}.#{m_data["file"]["field"]}.url.split('/').last,",
                  "                       disposition: 'attachment',",
                  "                       stream: 'true',",
                  "                       buffer_size: '4096'",
                  "end"
                ]
              } unless m_data["controller_public_methods"].has_key?("download")
            end
          end
        end
      end
    end

    def expand_special_data_for_universals
      ((@scheme['specials'] || {})['universals'] || {}).each do |universal|
        exceptions = universal["exceptions"] || []
        properties = universal["properties"]
        @scheme['models'].each do |m_name, m_data|
          next if exceptions.include?(m_name)
          m_data['concerns'] = properties['concerns'] + (m_data['concerns'] || []) if properties.has_key?('concerns')
          if properties.has_key?('relationships')
            m_data['relationships'] = {} unless m_data.has_key?('relationships')
            m_data['relationships'] = Marshal.load(Marshal.dump(properties['relationships'])).deep_merge(m_data['relationships'] || {}) # warning: deep_merge could lead to some silly bs like { type: :belongs_to, belongs_to: { ... }, has_many: { ... } }... undesirable, but should have no effect.
          end
        end
      end
    end

    def hash_drill(hash, &block)
      raise ArgumentError.new("hash_drill requires a block") unless block_given?
      subhashes = block.call(hash) || []
      subhashes.each{|subhash| hash_drill(subhash, &block) }
    end

    def expand_multi_fields
      (@scheme['models'] || {}).each do |m_name, m_data|
        (m_data['fields'] || {}).select{|f_name, f_data| f_name[0,1] == "[" }.each do |f_name, f_data|
          farr = JSON.parse(f_name).map{|e| e.to_s }
          farr.each{|fn| m_data['fields'][fn] = Marshal.load(Marshal.dump(f_data)) }
          m_data['fields'].delete(f_name)
        end
      end
    end

    def perform_field_autoexpansions
      (@scheme['models'] || {}).each do |m_name, m_data|
        next unless m_data.has_key?('autoexpansions') && m_data['autoexpansions'].has_key?('fields')
        puts "    Autoexpanding fields for model #{m_name}..."
        (m_data['autoexpansions']['fields'].class == ::Array ? m_data['autoexpansions']['fields'] : [m_data['autoexpansions']['fields']]).each do |fax_str|
          fax = instance_eval(fax_str)
          (m_data['fields'] || {}).each do |f_name, f_data|
            fax.call(f_name, f_data)
          end
        end
      end
    end

    def expand_namespace_groupings
      return unless @scheme.has_key?('namespaces')
      # create hash with groupings as keys and arrays of members as values (NameSpace Group Hash = nsgh)
      nsgh = Hash.new{|h,k| h[k] = [] }
      @scheme['namespaces'].each do |ns_name, ns_data|
        (ns_data['groupings'] || []).each do |g_name|
          nsgh[g_name].push(ns_name)
        end
      end
      # perform expansions
      # MOOSE WARNING: this is very brittle! only namespace uses in the scheme that we explicitly handle here will support group expansion!!!!!!
      nsgh.each do |g_name, ns_names|
        # define useful array-expansion lambda
        expand = lambda do |val|
          if val.class == ::Array
            val.replace(val.flat_map{|ns| ns == g_name ? ns_names : ns }.uniq)
          elsif val.class == ::Hash && val.has_key?(g_name)
            ns_names.each{|ns_name| val[ns_name] = Marshal.load(Marshal.dump(val[g_name])) unless val.has_key?(ns_name) }
            val.delete(g_name)
          end
        end
        # expand namespace stuff
        if @scheme['namespaces'].has_key?(g_name)
          ns_names.each do |ns_name|
            @scheme['namespaces'][ns_name] = @scheme['namespaces'][g_name].merge(@scheme['namespaces'][ns_name] || {}) # WARNING: not deep_merge
          end
          @scheme['namespaces'].delete(g_name)
        end
        # expand specials history namespaces
        expand.call(@scheme.dig('specials', 'history', 'namespaces'))
        # expand model stuff
        (@scheme['models'] || {}).each do |m_name, m_data|
          # expand model ownerless list
          expand.call(m_data['ownerless'])
          # expand model field permissions
          (m_data['fields'] || {}).each{|f_name, f_data| expand.call(f_data['permissions']) }
          # expand model relationship permissions & controller_defaults # MOOSE WARNING: are we missing any other things here???
          hash_drill(m_data['relationships'] || {}) do |hash|
            subhashes = []
            hash.each do |r_name,r_data|
              expand.call(r_data['permissions'])
              expand.call(r_data['controller_defaults'])
              subhashes.push(r_data['wherethrough']) if r_data.has_key?('wherethrough')
            end
            subhashes
          end
          # expand model index_source_override, fixed_filters, and actions
          expand.call(m_data['index_source_override'])
          expand.call(m_data['fixed_filters'])
          expand.call(m_data['actions'])
          # expand action customizations
          (m_data['action_customizations'] || {}).each{|cust_type, cust_data| expand.call(cust_data) }
          # expand model controller_public_methods and controller_private_methods
          ['public','private'].each{|visibility| (m_data["controller_#{visibility}_methods"] || {}).each{|meth_name, meth_data| expand.call(meth_data['namespaces']) } }
          (m_data["custom_views"] || {}).each{|cv_name, cv_data| expand.call(cv_data['namespaces']) }
        end
      end
    end

end
















