require 'rake'

namespace :gc do
  
  namespace :reset do
      
    desc "total Get Covered local reset"
    task total: :environment do
    	Rake::Task['gc:flush:schema'].invoke
    	
    	['setup', 'agency', 'account', 'insurable', 'user', 'policy'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end  
    
    desc "data Get Covered local reset"
    task data: :environment do
    	Rake::Task['gc:flush:all'].invoke
    	
    	['setup', 'agency', 'account', 'insurable', 'user', 'policy'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end
    
  end
  
  namespace :flush do
  	
  	desc "remove and rebuild databases"
  	task all: :environment do
    	Rake::Task['db:drop'].invoke
    	Rake::Task['db:create'].invoke
    	Rake::Task['db:migrate'].invoke
    end
  	
  	desc "remove and rebuild databases / schema"
  	task schema: :environment do
    	Rake::Task['db:drop'].invoke
    	
    	system("rm -rf db/schema.rb")
    	
    	Rake::Task['db:create'].invoke
    	Rake::Task['db:migrate'].invoke
    end
    
  end

end
