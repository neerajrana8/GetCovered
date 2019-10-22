require 'roo'
require File.join(__dir__, '/hash_manipulation_tools.rb')

=begin
  HASH FORMAT CHANGES FROM APP_GENERATOR:
    1) 'verbs' instead of 'actions'
    2) 'scopeless' instead of 'ownerless'
    3) 'both' instead of 'mutable' in field permissions
    4) added 'no_sort' permission to override sortability
=end

############## SETUP

$show_debug_stuff = false
$allow_unknown_models = false
$allow_unknown_fields = false
$allow_unknown_associations = false # MOOSE WARNING: currently true is unsupported here!!!

# read scheme
$scheme = JSON.parse(File.read(File.join(__dir__, "app-data/scheme.json")))

# extract spreadsheet data
$xlsx = Roo::Spreadsheet.open(File.join(__dir__, "app-data/generation_spreadsheet.xlsx"))

# spreadsheet parameters
$contexts = ['user', 'staff_account', 'staff_agency', 'staff_super_admin', 'public']
$ctx_verbs = ['create', 'update', 'destroy', 'index', 'show']

############## UTILITIES

# monkey bois
class String
  def special_strip
    self.strip.downcase.split('*').join('').split('?').join('')
  end
end

# warning logger
$logged_warnings = []
def log_warning(summary, description = nil, longform_data = nil)
  $logged_warnings.push({ summary: summary, description: description, longform_data: longform_data })
  puts "WARNING(#{$logged_warnings.size - 1}): #{summary}#{description.nil? ? "" : "; #{description}"}#{longform_data.nil? ? "" : " (extra data available)"}"
end

# row range getter
def get_row_range(sheet, start_row, consec_empties_allowed = 0, columns_to_check = [1])
  empties_count = 0
  cur_row = start_row
  while empties_count <= consec_empties_allowed
    is_empty = true
    columns_to_check.each{|cur_col| is_empty = false unless sheet.cell(cur_row, cur_col).blank? }
    if is_empty
      empties_count += 1
    else
      empties_count = 0
    end
    cur_row += 1
  end
  cur_row -= empties_count + 1
  return (start_row..cur_row)
end

# return fancy field types to equivalents that the script actually handles
def desublimate_field_type(field_type)
  {
    'belongs_to_key' => 'integer',
    'belongs_to_type' => 'string'
  }[field_type] || field_type
end

# get default filtrations for a type
def default_filtrations_for(field_type)
  default_filtrations = {
    'array' => [],
    'boolean' => [ 'scalar'],
    'date' => [ 'scalar', 'array', 'interval' ],
    'datetime' => [ 'scalar', 'array', 'interval' ],
    'enum' => [ 'scalar', 'array' ],
    'hstore' => [],
    'integer' => [ 'scalar', 'array', 'interval' ],
    'jsonb' => [],
    'string' => [ 'scalar', 'array', 'like' ],
    'text' => [],
    'decimal' => [ 'scalar', 'array', 'interval' ]
  }
  return (default_filtrations[desublimate_field_type(field_type)] || nil) # just to be clear that we really do want missing types to return nil
end

# check if a filtration is validly applicable to a type
def validate_filtration(field_type, filtration)
  allowed_filtrations = {
    'array' => [],
    'boolean' => [ 'scalar', 'array' ],
    'date' => [ 'scalar', 'array', 'interval' ],
    'datetime' => [ 'scalar', 'array', 'interval' ],
    'enum' => [ 'scalar', 'array' ],
    'hstore' => [], # none
    'integer' => [ 'scalar', 'array', 'interval' ],
    'jsonb' => [], # filter_method_property_filters is used for dynamic magics in AppGenerator
    'string' => [ 'scalar', 'array', 'like' ],
    'text' => [ 'scalar', 'array', 'like' ],
    'decimal' => [ 'scalar', 'array', 'interval' ]
  }
  return (allowed_filtrations[desublimate_field_type(field_type)] || []).include?(filtration)
end


############## ENCAPSULATED FUNCTIONALITY



def handle_models_sheet(sheet)
  puts "Handling Models..." if $show_debug_stuff
  get_row_range(sheet, 5).each do |row|
    # setup for model
    if sheet.cell(row, 1).blank?
      puts "  Model: (blank)" if $show_debug_stuff
      next
    end
    m_name = sheet.cell(row, 1).strip
    puts "  Model: #{m_name}" if $show_debug_stuff
    m_data = $scheme['models'][m_name]
    if m_data.nil?
      log_warning("Unknown model '#{m_name}' encountered: #{$allow_unknown_models ? 'inserting' : 'ignoring'}")
      if $allow_unknown_models
        $scheme['models'][m_name] = {}
      else
        next
      end
    end
    # get verbs
    m_data['verbs'] = {} if !m_data.has_key?('verbs')
    verbs = $contexts.map{|ctx| [ctx, []] }.to_h
    m_data['verbs'] = $contexts.map{|ctx| [ctx, ((m_data['verbs'] || {})[ctx] || []).select{|verb| !$ctx_verbs.include?(verb) }] }.to_h
                                        .merge((m_data['verbs'] || {}).select{|k,v| !$contexts.include?(k) }) # preserve verbs the spreadsheet doesn't deal with, remove others, ensure there's an array for us to put things in
    $contexts.each_with_index do |ctx, ctx_index|
      ctx_col = 2 + ctx_index * $ctx_verbs.length
      $ctx_verbs.each_with_index do |verb, verb_index|
        col = ctx_col + verb_index
        if sheet.cell(row,col).to_s.special_strip == "yes"
          m_data['verbs'][ctx].push(verb)
          puts "    #{ctx} has verb: #{verb}" if $show_debug_stuff
        end
      end
    end
    # get scopes
    m_data['access_model'] = {} if !m_data.has_key?('access_model')
    m_data['access_model'] = (m_data['access_model'] || {}).select{|context| !$contexts.include?(context) } # destroy data we're about to read from the spreadsheet
    $contexts.each_with_index do |ctx, ctx_index|
      col = 2 + $contexts.length * $ctx_verbs.length + ctx_index
      if sheet.cell(row, col).to_s.special_strip == 'unscoped'
        m_data['access_model'][ctx] = "model_class"
        puts "    model is scopeless for #{ctx}" if $show_debug_stuff
      end
    end
    # get route mounts
    col = 2 + $contexts.length * ($ctx_verbs.length + 1)
    val = sheet.cell(row, col).to_s.special_strip
    unless val.blank?
      mount_points = val.split(',').map{|v| v.strip }.select do |mount_point|
        unless mount_point == 'nil' || @scheme['models'].has_key?(mount_point)
          log_warning("Invalid mount point '#{mount_point}' encountered for model '#{m_name}'; ignoring")
          next
        end
        m_data['route_mounts'] = [] unless m_data.has_key?('route_mounts')
        m_data['route_mounts'].push({
          'mount_path' => [mount_point == 'nil' ? nil : mount_point]
          #'contexts': [], but we don't differentiate between contexts right now
        })
      end
    end
    # get history
    col = 3 + $contexts.length * ($ctx_verbs.length + 1)
    val = sheet.cell(row, col).to_s.special_strip.split(',').map{|v| v.strip }
    if val.include?('verbs')
      m_data['specials'] = {} unless m_data.has_key?('specials')
      m_data['specials']['history'] = {} unless m_data['specials'].has_key?('history')
      m_data['specials']['history']['history_verbs'] = true
    end
    if val.include?('author_verbs')
      m_data['specials'] = {} unless m_data.has_key?('specials')
      m_data['specials']['history'] = {} unless m_data['specials'].has_key?('history')
      m_data['specials']['history']['author_verbs'] = true
    end
  end
end

def handle_fields_sheet(sheet)
  puts "Handling Fields..." if $show_debug_stuff
  m_name = nil
  get_row_range(sheet, 6).each do |row|
    # setup for model & field
    if sheet.cell(row, 1).blank?
      puts "  Model: (blank)" if $show_debug_stuff
      next
    end
    if sheet.cell(row, 1).strip != m_name
      m_name = sheet.cell(row, 1).strip
      puts "  Model: #{m_name}" if $show_debug_stuff
      m_name = sheet.cell(row, 1).strip
    end
    if sheet.cell(row, 2).blank?
      log_warning("Blank field on row #{row} for model #{m_name}")
      next
    end
    m_data = $scheme['models'][m_name]
    if m_data.nil?
      log_warning("Unknown model '#{m_name}' encountered: #{$allow_unknown_models ? 'inserting' : 'ignoring'}")
      if $allow_unknown_models
        $scheme['models'][m_name] = {}
      else
        next
      end
    end
    m_data['fields'] = {} if !m_data.has_key?('fields')
    f_name = sheet.cell(row, 2).strip
      puts "    #{f_name}:" if $show_debug_stuff
    if !m_data['fields'].has_key?(f_name)
      log_warning("Unknown field '#{f_name}' encountered (model '#{m_name}', row #{row}): #{$allow_unknown_fields ? 'inserting' : 'ignoring'}")
      if $allow_unknown_fields
        field_type = sheet.cell(row, 3).to_s.strip
        if field_type.blank?
          log_warning("Unable to insert field #{m_name}##{f_name} on row #{row}: no type information")
          next
        else
          m_data['fields'][f_name] = { type: field_type }
        end
      else
        next
      end
    end
    f_data = m_data['fields'][f_name]
    # get permissions
    f_data['permissions'] = (f_data['permissions'] || {}).select{|k,v| !$contexts.include?(k) }.merge($contexts.map{|ctx| [ctx, []] }.to_h)
    $contexts.each_with_index do |ctx, ctx_index|
      ctx_col = 4 + ctx_index * 4
      # write
      col = ctx_col + 1
      perm = sheet.cell(row, col).to_s.special_strip
      if ['both', 'create', 'update'].include?(perm)
        f_data['permissions'][ctx].push(perm)
      elsif !perm.blank?
        log_warning("Unknown write permission '#{perm}' encountered for field #{m_name}##{f_name}")
      end
      # read
      col = ctx_col
      perm = sheet.cell(row, col).to_s.special_strip
      if ['short','index','show'].include?(perm)
        f_data['permissions'][ctx].push(perm)
      elsif !perm.blank?
        log_warning("Unknown read permission '#{perm}' encountered for field #{m_name}##{f_name}")
      end
      # filter
      col = ctx_col + 2
      filter_perms_blank = false
      perm = sheet.cell(row, col).to_s.special_strip
      if perm == 'yes'
        perm = default_filtrations_for(f_data['type'])
        if perm.nil?
          log_warning("Default filter permissions uknown for type #{''}", "arose in considering #{m_name}##{f_name} for context '#{ctx}', row #{row}")
        else
          f_data['permissions'][ctx].push(*perm)
        end
      elsif perm == 'no' || perm.blank?
        filter_perms_blank = true
      else
        perm = perm.split(',').map{|p| p.strip }.filter do |p|
          allowed = validate_filtration(f_data['type'], p)
          unless allowed
            log_warning("Filter permission '#{p}' invalidly applied to field of type '#{f_data['type']}'", "arose in considering #{m_name}##{f_name} for context '#{ctx}', row #{row}")
          end
          allowed
        end
        filter_perms_blank = true if perm.length == 0
        f_data['permissions'][ctx].push(*perm)
      end
      # sort
      col = ctx_col + 3
      perm = sheet.cell(row, col).to_s.special_strip
      if perm == 'yes'
        f_data['permissions'][ctx].push('sort')
      elsif perm == 'no'
        f_data['permissions'][ctx].push('no_sort') unless filter_perms_blank
      elsif perm.blank?
        unless filter_perms_blank
          f_data['permissions'][ctx].push('sort')
        end
      else
        log_warning("Unknown sort permission '#{perm}' encountered for field #{m_name}##{f_name}")
      end
      puts "      #{ctx}: #{f_data['permissions'][ctx].join(', ')}" if $show_debug_stuff && !f_data['permissions'][ctx].blank?
    end
  end
end

def handle_associations_sheet(sheet)
  puts "Handling Associations..." if $show_debug_stuff
  m_name = nil
  get_row_range(sheet, 6).each do |row|
    # setup for model & field
    if sheet.cell(row, 1).blank?
      puts "  Model: (blank)" if $show_debug_stuff
      next
    end
    if sheet.cell(row, 1).strip != m_name
      m_name = sheet.cell(row, 1).strip
      puts "  Model: #{m_name}" if $show_debug_stuff
      m_name = sheet.cell(row, 1).strip
    end
    if sheet.cell(row, 5).blank?
      log_warning("Blank association on row #{row} for model #{m_name}")
      next
    end
    m_data = $scheme['models'][m_name]
    if m_data.nil?
      log_warning("Unknown model '#{m_name}' encountered: #{$allow_unknown_models ? 'inserting' : 'ignoring'}")
      if $allow_unknown_models
        $scheme['models'][m_name] = {}
      else
        next
      end
    end
    m_data['associations'] = {} if !m_data.has_key?('associations')
    a_name = sheet.cell(row, 5).strip
      puts "    #{a_name}:" if $show_debug_stuff
    if !m_data['associations'].has_key?(a_name)
      log_warning("Unknown association '#{a_name}' encountered (model '#{m_name}', row #{row}): #{$allow_unknown_associations ? 'inserting' : 'ignoring'}")
      if $allow_unknown_fields
        next # MOOSE WARNING: add support for allow_unknown_associations = true here
      else
        next
      end
    end
    a_data = m_data['associations'][a_name]
    # get permissions
    a_data['permissions'] = (a_data['permissions'] || {}).select{|k,v| !$contexts.include?(k) }.merge($contexts.map{|ctx| [ctx, []] }.to_h)
    $contexts.each_with_index do |ctx, ctx_index|
      ctx_col = 6 + ctx_index * 7
      # READ
      { 'short' => 0, 'index' => 1, 'show' => 2 }.each do |view, index_offset|
        col = ctx_col + index_offset
        perm = sheet.cell(row, col).to_s.special_strip
        if ['short','index','show','short_fields','index_fields','show_fields'].include?(perm)
          a_data['permissions'][ctx].push("#{view}_#{perm}")
        elsif perm == 'no' || perm.blank?
          # do nothing
        else
          # custom
          a_data['permissions'][ctx].push("#{view}_#{perm}")
        end
      end
      # MUTATE
      { 'create' => 3, 'update' => 4 }.each do |mutation, index_offset|
        col = ctx_col + index_offset
        perm = sheet.cell(row, col).to_s.special_strip
        if ['create', 'update'].include?(perm)
          a_data['permissions'][ctx].push("#{mutation}_#{perm}")
        elsif perm == 'no' || perm.blank?
          # do nothing
        else
          # custom
          a_data['permissions'][ctx].push("#{mutation}_#{perm}")
        end
      end
      # DESTROY
      col = ctx_col + 5
      perm = sheet.cell(row, col).to_s.special_strip
      if perm == 'yes'
        a_data['permissions'][ctx].push(*["create_destroy", "update_destroy"])
      end
      # QUERY
      col = ctx_col + 6
      perm = sheet.cell(row, col).to_s.special_strip
      if perm == 'yes'
        a_data['permissions'][ctx].push('queriable')
      end
      # scream out to the user
      puts "      #{ctx}: #{a_data['permissions'][ctx].join(', ')}" if $show_debug_stuff && !a_data['permissions'][ctx].blank?
    end
  end
end


############## EXECUTION

# contract through associations
contract_through_associations($scheme){|model, assoc, through_assoc| log_warning("Multiple scheme definitions for association #{model}##{assoc} (through '#{through_assoc}')") }

# models
sheets_handled = []
$xlsx.each_with_pagename do |sheetname, sheet|
  case sheetname
    when 'Models'
      handle_models_sheet(sheet)
    when 'Fields'
      handle_fields_sheet(sheet)
    when 'Associations'
      handle_associations_sheet(sheet)
    else
      log_warning("Unknown sheet '#{sheetname}' encountered")
  end
  sheets_handled.push(sheetname)
end

# make sure critical sheets were handled
['Models', 'Fields', 'Associations'].each do |sheetname|
  log_warning("Did not encounter/handle '#{sheetname}' sheet as expected") unless sheets_handled.include?(sheetname)
end

# expand through associations
expand_through_associations($scheme){|model, assoc, through_assoc| log_warning("Hideously botched through association #{model}##{assoc} (through '#{through_assoc}') encountered in scheme") }

# spit out the hash
File.open(File.join(__dir__, "app-data/scheme.json"), "w") do |f|
  f.write(JSON.pretty_generate($scheme))
end
