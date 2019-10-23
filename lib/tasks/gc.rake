require 'rake'

namespace :gc do
  
  namespace :reset do
      
    desc "total Get Covered local reset"
    task total: :environment do
    	Rake::Task['gc:flush:schema'].invoke
    	Rake::Task['gc:flush:elasticsearch'].invoke
    	Rake::Task['gc:flush:redis'].invoke
    	
    	['setup', 'agency', 'account', 'insurable-residential', 
	  	 'insurable-commercial', 'user', 'policy-residential', 
			 'policy-commercial'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end  
    
    desc "data Get Covered local reset"
    task data: :environment do
    	Rake::Task['gc:flush:all'].invoke
    	Rake::Task['gc:flush:elasticsearch'].invoke
    	Rake::Task['gc:flush:redis'].invoke
    	
    	['setup', 'agency', 'account', 'insurable-residential', 
	  	 'insurable-commercial', 'user', 'policy-residential', 
			 'policy-commercial'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end
    
    namespace :aws do
      desc "total Get Covered AWS Dev Reset"
      task :dev do
        Rake::Task['db:migrate'].invoke
        
      	['setup', 'agency', 'account', 'insurable-residential', 
  	  	 'insurable-commercial', 'user', 'policy-residential', 
  			 'policy-commercial'].each do |section|
      		system("rails db:seed section=#{ section }")
      	end        
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
    
    desc "remove all elasticsearch indexes"
		task elasticsearch: :environment do
			system("curl -XDELETE http://localhost:9200/_all")
		  puts "\n"
		end   
		
		desc "remove all redis keys"
		task redis: :environment do
		  system("redis-cli FLUSHALL")
		  puts "\n"
		end 
  end

end
