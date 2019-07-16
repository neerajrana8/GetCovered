require 'rake'

namespace :gc do

  desc "total Get Covered local reset"
  task reset: :environment do
  	Rake::Task['db:drop'].invoke
  	
  	system("rm -rf db/schema.rb")
  	
  	Rake::Task['db:create'].invoke
  	Rake::Task['db:migrate'].invoke
  	
  	['setup', 'agency', 'account', 'insurable', 'user', 'policy'].each do |section|
  		system("rails db:seed section=#{ section }")
  	end
  end

end
