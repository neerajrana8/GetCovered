require 'rake'

namespace :gc do
  
  namespace :reset do
      
    desc "total Get Covered local reset"
    task total: :environment do
    	Rake::Task['gc:flush:schema'].invoke
    	Rake::Task['gc:flush:redis'].invoke
    	
    	['setup', 'agency', 'account', 'insurable-residential',
       'insurable-cambridge', 'insurable-commercial', 'user', 
       'policy-residential', 'branding-profiles', 'set-permissions'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end  
    
    desc "data Get Covered local reset"
    task data: :environment do
    	Rake::Task['gc:flush:all'].invoke
    	Rake::Task['gc:flush:redis'].invoke
    	
    	['setup', 'agency', 'account', 'insurable-residential',
       'insurable-cambridge', 'insurable-commercial', 'user', 
       'policy-residential', 'branding-profiles', 'set-permissions'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end
    
    desc "data Get Covered local reset"
    task test: :environment do
    	Rake::Task['gc:flush:all'].invoke
    	Rake::Task['gc:flush:redis'].invoke
    	
    	['setup', 'agency', 'account'].each do |section|
    		system("rails db:seed section=#{ section }")
    	end
    end
    
    namespace :aws do
      desc "total Get Covered AWS Dev Reset"
      task :dev do
  		        
      	['setup', 'agency', 'account', 'insurable-residential',
      	 'insurable-cambridge', 'insurable-commercial', 'user', 
      	 'policy-residential', 'policy-commercial', 'branding-profiles', 'set-permissions'].each do |section|
      		system("rails db:seed section=#{ section }")
      	end        
      end
    end
    
		desc "Reset Dev / Staging Environment and Database"
		task development: :environment do
		  system("rails db:seed section=reset")
			Rake::Task['db:migrate'].invoke
			
			system("rails db:seed section=staging")
		end 
    
		desc "Reset Production Environment and Database"
		task production: :environment do
		  system("rails db:seed section=reset")
		  puts "\n"
			Rake::Task['db:migrate'].invoke
			system("rails db:seed section=production")
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
		
		desc "remove all redis keys"
		task redis: :environment do
		  system("redis-cli FLUSHALL")
		  puts "\n"
		end 
  end
  
  namespace :aws do
  
  	desc "Push to all aws instances"
  	task :all do
  		Rake::Task['gc:aws:api:dev'].invoke
  		Rake::Task['gc:aws:api:staging'].invoke
  		Rake::Task['gc:aws:api:production'].invoke
  		Rake::Task['gc:aws:worker:dev'].invoke
  		Rake::Task['gc:aws:worker:staging'].invoke
  		Rake::Task['gc:aws:worker:production'].invoke
  	end
    
    namespace :api do
      
      desc "Push development API Image"
      task :dev do
        system("$(aws ecr get-login --no-include-email --region us-west-2 --profile dylanmbda) && docker build -f Dockerfile -t get-covered-api-dev:v2dev . && docker tag get-covered-api-dev:v2dev 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-api-dev:v2dev && docker push 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-api-dev:v2dev")
      end
      
      desc "Push staging API Image"
      task :staging do
        system("$(aws ecr get-login --no-include-email --region us-west-2 --profile dylanmbda) && docker build -f Dockerfile -t get-covered-api-dev:staging . && docker tag get-covered-api-dev:staging 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-api-dev:staging && docker push 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-api-dev:staging")
      end
      
      desc "Push production API Image"
      task :production do
        system("$(aws ecr get-login --no-include-email --region us-west-2 --profile dylanmbda) && docker build -f Dockerfile -t get-covered-api-dev:production . && docker tag get-covered-api-dev:production 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-api-dev:production && docker push 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-api-dev:production")
      end
      
    end
    
    namespace :worker do
      
      desc "Push development Worker Image"
      task :dev do
        system("$(aws ecr get-login --no-include-email --region us-west-2 --profile dylanmbda) && docker build -f Dockerfile-worker -t get-covered-worker-dev:v2dev . && docker tag get-covered-worker-dev:v2dev 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-worker-dev:v2dev && docker push 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-worker-dev:v2dev")
      end
      
      desc "Push staging Worker Image"
      task :staging do
        system("$(aws ecr get-login --no-include-email --region us-west-2 --profile dylanmbda) && docker build -f Dockerfile-worker -t get-covered-worker-dev:staging . && docker tag get-covered-worker-dev:staging 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-worker-dev:staging && docker push 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-worker-dev:staging")
      end
      
      desc "Push production Worker Image"
      task :production do
        system("$(aws ecr get-login --no-include-email --region us-west-2 --profile dylanmbda) && docker build -f Dockerfile-worker -t get-covered-worker-dev:production . && docker tag get-covered-worker-dev:production 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-worker-dev:production && docker push 633634809203.dkr.ecr.us-west-2.amazonaws.com/get-covered-worker-dev:production")
      end
          
    end
    
  end

end
