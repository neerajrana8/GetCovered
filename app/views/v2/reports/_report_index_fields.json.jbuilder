json.extract! report, :id, :type,  :range_start, :range_end, :reportable_type,
                      :reportable_id, :created_at, :name, :available_formats

if params[:with_data]
  json.data report.data
end
