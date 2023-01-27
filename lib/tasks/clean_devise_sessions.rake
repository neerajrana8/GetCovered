# Tasks for managing leads data
namespace :device do
  desc 'Clean device sessions for staff & users'
  task :clean_sessions => :environment do

    Staff.in_batches do |staff_batch|
      staff_batch.update_all(tokens: {})
    end

    User.in_batches do |user_batch|
      user_batch.update_all(tokens: {})
    end
  end
end
