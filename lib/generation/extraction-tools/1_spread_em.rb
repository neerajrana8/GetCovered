require File.join(__dir__, '/hash_manipulation_tools.rb')


# utilities
def get_field_type_string(f_data)
  to_return = f_data['type'] # for now we just directly return the type, no special markup like including enum options etc... but this is here in case we want to add that later
  return to_return
end
def get_association_type_string(a_data)
  to_return = a_data['type']
  to_return = "#{to_return}(#{a_data['target'].join(',')})" unless a_data['target'].blank?
  return to_return
end


# prepare
scheme_file = File.read(File.join(__dir__, "scheme.json"))
scheme = JSON.parse(scheme_file)
models_csv = ""
fields_csv = ""
associations_csv = ""



# build models csv
models_csv = scheme['models'].keys.join("\n")

# build fields csv
fields_csv = scheme['models'].map{|mk, mv| mv['fields'].map{|fk,fv| [mk, fv['name'], fv['type']].join(',') } }.flatten.join("\n")

# build associations csv
associations_csv = scheme['models'].map{|mk, mv| mv['associations'].map{|ak,av| [mk, av['type'], "\"#{av['target'].join(',')}\"", av['through'] || '', ak].join(',') } }.flatten.join("\n")



# spit out csvs MOOSE WARNING: change this to use Roo to spit out an xlsx
['models', 'fields', 'associations'].each do |csv_thang|
  File.open(File.join(__dir__, "app-data/#{csv_thang}.csv"), "w") do |f|
    f.write(eval("#{csv_thang}_csv"))
  end
end
