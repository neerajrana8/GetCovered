# Tasks for managing leads data
namespace :device do
  desc 'Clean device sessions for staff users'
  task :clean_sessions => :environment do
    Staff.where('JSONB_ARRAY_LENGTH(tokens) > 5').update_all(tokens: {})
  end
end
