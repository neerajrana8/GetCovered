conn = ActiveRecord::Base.connection
tables = conn.tables
tables.each do |t|
  ActiveRecord::Base.connection.execute("DROP TABLE #{t} CASCADE;") if ActiveRecord::Base.connection.data_source_exists? t
end