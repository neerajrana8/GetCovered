##
# V1 Controller
# file: app/controllers/v1_controller.rb



# MOOSE WARNING: THINGS TO DO TO IMPROVE EFFICIENCY:
# (1) Remove SQL parse method.
# (2) Use only passed includes as includes.
# (3) Convert includes from WHERE clauses to joins; get rid of handle_order's custom joins and integrate them into the joins tree.
# Results will be:
#   (1) Table aliases remain consistent (extra unused aliases from the initial includes will get their names after the joins have been given theirs);
#   (2) LEFT OUTER JOINs get replaced with LEFT INNER JOINs, reducing time and memory usage;
#   (3) Extra joins when sorts repeat pre-loaded SQL joins will be eliminated.
# ALSO:
# (1) Implement support for "distinct" has_many relationships and for "where" scopes... maybe.


class V2Controller < ApplicationController

  around_action :set_timezone

  def index(instance_symbol, data_source, *includes)
#puts data_source.to_sql
#exit
    prequery = build_prequery(data_source, includes, (params[:filter].nil? ? {} : params[:filter].to_unsafe_h).deep_merge(fixed_filters), params[:sort].nil? ? nil : params[:sort].to_unsafe_h)
#ap "Prequery: #{prequery}"
    query = build_query(data_source, prequery)

#print "\nQuery: #{query.to_sql}\n"

=begin
puts ''
puts params
puts ''
puts prequery
puts ''
puts query.to_sql
exit
=end
    last_id = nil
    if params[:short]
      instance_variable_set(instance_symbol, pseudodistinct ? query.select{|m| if m.id == last_id then next(false) else last_id = m.id end; next(true) } : query)
      render template: (view_path + '/short.json.jbuilder') if v2_should_render[:short]
    else
      count = query.count
      per = (params.has_key?(:pagination) && params[:pagination].has_key?(:per)) ? params[:pagination][:per].to_i : default_pagination_per
      if per <= 0
        per = default_pagination_per
      elsif per > maximum_pagination_per
        per = maximum_pagination_per
      end
      page_count = count == 0 ? 1 : (count.to_f / per).ceil
      page = (params.has_key?(:pagination) && params[:pagination].has_key?(:page)) ? params[:pagination][:page].to_i : 0
      response.headers['current-page'] = page.to_s
      response.headers['total-pages'] = page_count.to_s
      response.headers['total-entries'] = count.to_s
      instance_variable_set(instance_symbol, pseudodistinct ? query.page(page + 1).per(per).select{|m| if m.id == last_id then next(false) else last_id = m.id end; next(true) } : query.page(page + 1).per(per)) # pagination starts at page 1 with kaminary -____-
      render template: (view_path + '/index.json.jbuilder') if v2_should_render[:index]
    end
  end

  def apply_filters(instance_symbol, data_source, *includes)
    prequery = build_prequery(data_source, includes, (params[:filter].nil? ? {} : params[:filter].to_unsafe_h).deep_merge(fixed_filters), params[:sort].nil? ? nil : params[:sort].to_unsafe_h)
    query = build_query(data_source, prequery)
    instance_variable_set(instance_symbol, query)
  end

  #private

  def paginator(data_source, *includes)
    prequery = build_prequery(data_source, includes, (params[:filter].nil? ? {} : params[:filter].to_unsafe_h).deep_merge(fixed_filters), params[:sort].nil? ? nil : params[:sort].to_unsafe_h)
    query = build_query(data_source, prequery)
    count = query.count
    per = (params.has_key?(:pagination) && params[:pagination].has_key?(:per)) ? params[:pagination][:per].to_i : default_pagination_per
    per = default_pagination_per if per <= 0 || per > maximum_pagination_per
    page_count = count == 0 ? 1 : (count.to_f / per).ceil
    page = (params.has_key?(:pagination) && params[:pagination].has_key?(:page)) ? params[:pagination][:page].to_i : 0
    response.headers['current-page'] = page.to_s
    response.headers['total-pages'] = page_count.to_s
    response.headers['total-entries'] = count.to_s

    query.page(page + 1).per(per)
  end
  
  
  # control of what's rendered automatically; should probably both be true or both false, but backwards compatibility is a thing
  def v2_should_render
    { short: true, index: false }
  end

  # The default number of items per page.
  def default_pagination_per
    50
  end

  # The maximum allowed number of items per page.
  def maximum_pagination_per
    1000
  end

  # The filters allowed to be use: format is { property_name: type },
  # where either property_type is a data member of the model overriding it
  # and type is an array of choices from [ :scalar, :array, :like, :interval ],
  # or property_type is the name of an association of the model overriding it
  # and type is another hash with the same format, to be applied to the associated model.
  def supported_filters
    {}
  end

  # The properties allowed to be used in ORDER BY query statements:
  # same format as supported_filters except that only the keys of the hashes matter,
  # except of course for associations, where the value is expected to again be a hash of the same kind.
  def supported_orders
    supported_filters
  end

  # Used to construct the path to a model's short view.
  def view_path
    'v2'
  end

  # Override this to return a hash of filters which should always be in place
  def fixed_filters
    {}
  end

  # Override this to turn on pseudodistinct querying (verifies primary ids are unique after query)
  def pseudodistinct
    false
  end
  
  # Set substrate (useful controller method for generalized nested routes)
  def set_substrate
    unless params[:access_pathway].nil?
      @substrate = access_model(params[:access_pathway][0], params[params[:access_ids][0]])
      (1...params[:access_pathway].length).each do |n|
        @substrate = @substrate.send(params[:access_pathway][n].class == Class ? params[:access_pathway][n].name.pluralize.underscore : params[:access_pathway][n])
                               .send(*(params[params[:access_ids][n]].nil? ? [:itself] : [:find, params[params[:access_ids][n]]]))
      end
    end
  end

  def build_query(queriable, prequery)
    if queriable.class == ::Class
      queriable = queriable.all
    end
    queriable = queriable.includes(prequery[:includes]) unless prequery[:includes].blank?
    queriable = queriable.references(prequery[:references]) unless prequery[:references].blank?
    queriable = queriable.where({ queriable.table_name => prequery[:where_hash] }) unless prequery[:where_hash].blank?
    prequery[:where_strings].each do |where_string|
      queriable = queriable.where(where_string[0], where_string[1])
    end
    prequery[:joins].each_pair do |key, value|
      queriable = queriable.joins({key => value})
    end
    prequery[:orders].each do |order_string|
      queriable = queriable.order(order_string)
    end
    return(queriable)
  end

  def build_prequery(queriable, includes, filters, orders)
    # handle empty parameters
    includes = {} if includes.nil?
    filters = {} if filters.nil?
    orders = { column: [], direction: [] } if orders.nil?
    # reformat includes if necessary ( [:a, { b: :c, d: :e}] to { a: {}, b: :c, d: :e } )
    includes = reformat_array_hash(includes) if includes.class == ::Array
    # reformat orders if necessary ( { column: [ column_name, ... ], direction: [ direction_name, ... ] )
    orders[:column] = [] unless orders.has_key?(:column)
    orders[:direction] = [] unless orders.has_key?(:direction)
    orders[:column] = [ orders[:column] ] unless orders[:column].class == ::Array
    orders[:direction] = [ orders[:direction] ] unless orders[:direction].class == ::Array
    # create empty prequery hash
    prequery = {
      includes: {},
      references: {},
      joins: {},
      orders: [],
      where_hash: {},
      where_strings: {}
    }
    # put filters into prequery
    results = handle_filters(supported_filters, filters, queriable)
    prequery[:includes] = results[:includes]
    prequery[:references] = results[:references]
    # prequery[:joins] = results[:references]
    prequery[:where_hash] = results[:where_hash]
    prequery[:where_strings] = results[:where_strings]
    # put includes into prequery
    prequery[:includes].deep_merge!(includes)
    include_order_columns(queriable.class == ::Class ? queriable : queriable.model, prequery, orders) # this will also strip out order by columns that aren't allowed
    prequery[:references].deep_merge!(includes) # MOOSE WARNING: sometimes adding references causes includes not referenced to become joins rather than preloads, which may cause our handle_orders() to create redundant joins; as a stopgap for now, we make sure ALL references are also includes, though this isn't strictly optimal.
    # duplicate ActiveRecord's absurd table aliases and replace association names with table names where necessary
    table_names = get_table_names(queriable, prequery[:includes])
    table_names['$'] = queriable.table_name
    table_names['!'] = queriable.class == ::Class ? queriable : queriable.klass
    prequery[:references] = convert_references_to_table_names(prequery[:references], table_names)
    prequery[:where_hash] = convert_where_hash_to_table_names(prequery[:where_hash], table_names)
    prequery[:where_strings] = convert_where_strings_to_table_names(prequery[:where_strings], table_names)
    # put orders into prequery
    prequery[:orders] = stringify_orders(orders[:column], orders[:direction], table_names)
    # reformat include and references for the appropriate ActiveRecord methods
    prequery[:includes] = format_hash_for_active_record(prequery[:includes])
    prequery[:references] = format_hash_for_active_record(prequery[:references])
    # all done
    return(prequery)
  end

  def reformat_array_hash(array)
    to_return = {}
    array.each do |val|
      if val.class == ::Hash
        val.each do |key, value|
          if value.class == ::Array
            to_return[key] = reformat_array_hash(value)
          elsif value.class == ::Hash
            to_return[key] = reformat_array_hash([value])
          else
            to_return[key] = { value => {} }
          end
        end
      else
        to_return[val] = {}
      end
    end
    return(to_return)
  end

  def include_order_columns(model, prequery, orders)
    # woot
    includes = prequery[:includes]
    columns = orders[:column]
    directions = orders[:direction]
    # make sure we have a direction for each column
    while directions.length > columns.length
      directions.pop
    end
    while directions.length < columns.length
      directions.push("desc")
    end
    # slaughter invalid directions
    to_slaughter = []
    directions.each_with_index do |dir, dir_index|
      directions[dir_index] = dir.downcase
      to_slaughter.push(dir_index) if directions[dir_index] != 'asc' && directions[dir_index] != 'desc'
    end
    unless to_slaughter.blank?
      columns.delete_if.with_index{|_,index| to_slaughter.include?(index) }
      directions.delete_if.with_index{|_,index| to_slaughter.include?(index) }
    end
    #process by column
    to_slaughter = []
    columns.each_with_index do |col, col_index|
      # prepare to verify that we are allowed to sort by this column
      pieces = col.split('.')
      cur_supported = supported_orders
      cur_model = model
      cur_include = includes
      is_allowed = true
      # verify intermediate associations
      for i in (0...pieces.length - 1)
        piece_symbol = pieces[i].to_sym
        # flee if joining the supplied table for ordering is forbidden
        unless cur_supported.has_key?(piece_symbol) && cur_supported[piece_symbol].class == ::Hash && cur_model.reflections.has_key?(pieces[i])
          is_allowed = false
          break;
        end
        # create the next include if necessary, and advance cur_include, cur_model, and cur_supported
        cur_supported = cur_supported[piece_symbol]
        cur_model = cur_model.reflections[pieces[i]].klass
        if cur_include.has_key?(piece_symbol)
          cur_include = cur_include[piece_symbol]
        else
          cur_include[piece_symbol] = {}
          cur_include = cur_include[piece_symbol]
        end
      end
      is_allowed = false unless cur_supported.has_key?(pieces.last.to_sym)
      to_slaughter.push(col_index) unless is_allowed
    end
    # remove columns that we aren't allowed to sort by
    unless to_slaughter.blank?
      columns.delete_if.with_index{|_,index| to_slaughter.include?(index) }
      directions.delete_if.with_index{|_,index| to_slaughter.include?(index) }
    end
    # all done (we've already inserted any necessary includes)
  end

  def stringify_orders(columns, directions, table_names)
    to_return = []
    columns.each_with_index do |col, col_index|
      pieces = col.split('.')
      cur_table = table_names
      for i in (0...pieces.length - 1)
        cur_table = cur_table[pieces[i].to_sym]
      end
      to_return.push("#{cur_table['$']}.#{pieces.last} #{directions[col_index]}")
    end
    return(to_return)
  end

  def handle_orders(columns, directions, table_names)
    to_return = {
      joins: {},
      orders: []
    }
    joins = {}
    join_root_models = {}
    # make sure we have a direction for each column
    while directions.length > columns.length
      directions.pop
    end
    while directions.length < columns.length
      directions.push("desc")
    end
    # process by column
    join_count = 0
    supported_root = supported_orders
    for i in (0...columns.length)
      dir = ['asc', 'desc'].include?(directions[i].downcase) ? directions[i].downcase : 'desc'
      # prepare to verify that we are allowed to sort by this column
      pieces = columns[i].split('.')
      cur_join_root = nil
      cur_join = nil
      cur_table_name = table_names
      cur_supported = supported_root
      # verify intermediate associations
      for j in (0...pieces.length - 1)
        # flee if ordering by this column is forbidden
        unless cur_supported.has_key?(pieces[j].to_sym) && cur_supported[pieces[j].to_sym].class == ::Hash
          columns[i] = ''
          break
        end
        # create or extend a join if necessary
        if cur_join.nil?
          if cur_table_name.has_key?(pieces[j].to_sym)
            cur_table_name = cur_table_name[pieces[j].to_sym]
          else
            join_root_models[cur_table_name['$']] = cur_table_name['!'] # doesn't hurt to put this into join_root_models even if never used ('!' designates the class of the table)
            cur_join_root = { cur_table_name['$'] => { pieces[j].to_sym => {} } }
            cur_join = cur_join_root[cur_table_name['$']][pieces[j].to_sym]
          end
        else
          cur_join[pieces[j].to_sym] = {} unless cur_join.has_key?(pieces[j].to_sym)
          cur_join = cur_join[pieces[j].to_sym]
        end
        cur_supported = cur_supported[pieces[j].to_sym]
      end
      # verify sort column is allowed
      unless columns[i] == '' || !cur_supported.has_key?(pieces.last.to_sym)
        if cur_join.nil?
          # add order string to orders list
          to_return[:orders].push("#{cur_table_name['$']}.#{pieces.last} #{dir}")
        else
          # insert the constructed join table sequence into joins and move cur_join accordingly
          joins.deep_merge!(cur_join_root)
          cur_join = joins
          while !cur_join_root.blank?
            cur_join_root.each do |key, value| # there will only actually be one of these
              cur_join = cur_join[key]
              cur_join_root = cur_join_root[key]
            end
          end
          # add table alias to cur_join under '$' marker
          unless cur_join.has_key?('$')
            join_count += 1
            cur_join['$'] = "joined__order_table#{join_count}"
          end
          # add order string to orders list
          to_return[:orders].push("#{cur_join['$']}.#{pieces.last} #{dir}")
        end
      end
    end
    # fix up joins
    to_return[:joins] = []
    joins.each do |table_alias, associations|
      append_join_strings_to(to_return[:joins], join_root_models[table_alias], table_alias, associations)
    end
    # done
    return(to_return)
  end

  def append_join_strings_to(string_array, last_model, last_table, children)
    children.each do |assocsym, grandchildren|
      assoc = assocsym.to_s
      table_alias = grandchildren.has_key?('$') ? grandchildren.delete('$') : "joined__conn_table#{string_array.length}"
      if last_model.reflections[assoc].class == ::ActiveRecord::Reflection::BelongsToReflection
        # MOOSE WARNING: no support for polymorphism through a belongs_to: only through a has_one or has_many!
        string_array.push("LEFT OUTER JOIN \"#{last_model.reflections[assoc].table_name}\" \"#{table_alias}\"" +
                          " ON \"#{table_alias}\".\"#{last_model.reflections[assoc].active_record_primary_key}\" = \"#{last_table}\".\"#{last_model.reflections[assoc].foreign_key}\"")
      else
        string_array.push("LEFT OUTER JOIN \"#{last_model.reflections[assoc].table_name}\" \"#{table_alias}\"" +
                          " ON \"#{last_table}\".\"#{last_model.reflections[assoc].active_record_primary_key}\" = \"#{table_alias}\".\"#{last_model.reflections[assoc].foreign_key}\"" +
                          (last_model.reflections[assoc].type.nil? ? "" : " AND \"#{table_alias}\".\"#{last_model.reflections[assoc].type}\" = \"#{last_model.reflections[assoc].active_record.to_s}\""))
      end
      append_join_strings_to(string_array, last_model.reflections[assoc].klass, table_alias, grandchildren)
    end
  end

  def convert_references_to_table_names(references, table_names)
    to_return = {}
    references.each do |key, value|
      to_return[table_names[key]['$']] = convert_references_to_table_names(value, table_names[key])
    end
    return(to_return)
  end

  def convert_where_hash_to_table_names(where_hash, table_names)
    to_return = {}
    where_hash.each do |key, value|
      if value.class == ::Hash
        to_return[table_names[key]['$']] = convert_where_hash_to_table_names(value, table_names[key])
      else
        to_return[key] = value
      end
    end
    return(to_return)
  end

  def convert_where_strings_to_table_names(where_strings, table_names)
    to_return = []
    to_return.concat(where_strings.delete('$').each{|v| v.first.gsub!('$', table_names['$']) }) if where_strings.present? && where_strings['$'].present?
    where_strings.each do |key, value|
      to_return.concat(convert_where_strings_to_table_names(value, table_names[key]))
    end
    return(to_return)
  end

  def get_table_names(model, includes, parent = model.table_name, used = { parent => {} })
    to_return = {}
    includes.each do |key, value|
      # set the table name corresponding to includes[key]
      child_table_name = model.reflections["#{key}"].table_name
      if used.has_key?(child_table_name)
        if(used[child_table_name].has_key?(parent))
          used[child_table_name][parent] += 1
          to_return[key] = { '$' => "#{model.reflections["#{key}"].plural_name}_#{parent}_#{used[child][parent]}", '!' => model.reflections["#{key}"].klass }
        else
          used[child_table_name][parent] = 1
          to_return[key] = { '$' => "#{model.reflections["#{key}"].plural_name}_#{parent}", '!' => model.reflections["#{key}"].klass }
        end
      else
        used[child_table_name] = {}
        to_return[key] = { '$' => child_table_name, '!' => model.reflections["#{key}"].klass }
      end
      # recurse
      to_return[key].merge!(get_table_names( model.reflections["#{key}"].klass, value, child_table_name, used )) unless value.blank?
    end
    return(to_return)
  end

  def format_hash_for_active_record(hash)
    to_return = []
    hash.each do |key, value|
      if value.blank?
        to_return.push(key)
      else
        to_return.push({ key => format_hash_for_active_record(value) })
      end
    end
    return(to_return)
  end

  def handle_filters(supported, filters, model, recursing = false)
    supported = {} if supported.nil?
    filters = {} if filters.nil?
    includes_hash = {}
    references_hash = {}
    to_return = {
      includes: {},
      references: {},
      hash: {},
      string: { '$' => [] }
    }
    supported.each do |key, forms|
      if filters.has_key?("#{key}")
        value = filters["#{key}"]
        if forms.class == ::Hash
          # subobject
          if value.class == ::Hash || value.class == ::ActiveSupport::HashWithIndifferentAccess
            subresults = handle_filters(forms, value, model.reflections["#{key}"].klass, true)
            unless subresults[:includes].blank? && subresults[:references].blank? && subresults[:hash].blank? && subresults[:string].blank?
              # add includes
              if subresults[:includes].blank?
                to_return[:includes][key] = subresults[:includes]
              else
                includes_hash[key] = subresults[:includes]
              end
              # add references
              if subresults[:references].blank?
                to_return[:references][key] = subresults[:references]
              else
                references_hash[key] = subresults[:references]
              end
              # add where clauses
              to_return[:hash][key] = subresults[:hash] unless subresults[:hash].blank?
              subresults[:string].delete('$') if subresults[:string]['$'].blank?
              to_return[:string][key] = subresults[:string]
            end
          end
        else
          if value.class == ::Array
            # array of scalars
            to_return[:hash][key] = value.map{|v| v == '_NULL_' ? nil : v } if forms.include?(:array) # MOOSE WARNING: verify scalar nature of array elements?
          elsif value.class != ::Hash && value.class != ::ActiveSupport::HashWithIndifferentAccess
            # scalar
            to_return[:hash][key] = (value == '_NULL_' ? nil : value) if forms.include?(:scalar) # MOOSE WARNING: check string, integer, etc independently?
          elsif value.has_key?("like") && value.length == 1
            # like
            to_return[:string]['$'].push(["$.#{key} ILIKE ?", "%#{value["like"]}%"]) if forms.include?(:like)
          elsif value.keys.length == (value.keys & ["start", "end", "before", "after"]).length && (value.keys & ["start", "after"]).length < 2 && (value.keys & ["end", "before"]).length < 2 # WARNING: no support for inverted intervals
            # interval
            if forms.include?(:interval)
              if value.has_key?("after")
                to_return[:string]['$'].push(["$.#{key} > ?", "#{value["after"]}"])
              elsif value.has_key?("start")
                to_return[:string]['$'].push(["$.#{key} >= ?", "#{value["start"]}"])
              end
              if value.has_key?("before")
                to_return[:string]['$'].push(["$.#{key} < ?", "#{value["before"]}"])
              elsif value.has_key?("end")
                to_return[:string]['$'].push(["$.#{key} <= ?", "#{value["end"]}"])
              end
            end
          end
        end
      end
    end
    # do final array preparations if we've been given a class_name, and return
    to_return[:includes].deep_merge!(includes_hash) unless includes_hash.blank?
    to_return[:references].deep_merge!(references_hash) unless references_hash.blank?
    return(to_return) if recursing
    return({
      includes: to_return[:includes],
      references: to_return[:references],
      where_hash: to_return[:hash],
      where_strings: to_return[:string]
    })
  end

  def set_timezone
    if request.headers['HTTP_TIMEZONE'].present?
      zone = request.headers['HTTP_TIMEZONE']
      Time.use_zone(zone) { yield }
    else
      yield
    end
  end

  def health_check
    render json: { ok: true , node: "It's alive!", env: ENV['RAILS_ENV']}.to_json
  end
end
