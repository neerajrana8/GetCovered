require 'rake'

namespace :docker do

  desc "Reset Docker"
  task down: :environment do
    system("docker-compose down")
  end
  
  desc "Build Docker"
  task build: :environment do
    system("docker-compose build --parallel")
  end

  desc "Up Docker"
  task up: :environment do
    system("docker-compose up -d --force-recreate")
  end
  
  namespace :db do
  
	  desc "Create DB"
		task create: :environment do
			system("docker-compose run web rails db:create")
		end
		
	  desc "Migrate DB"
		task migrate: :environment do
			system("docker-compose run web rails db:migrate")
		end
		
	end
	
	desc "Install from Docker"
	task install: :environment do
		Rake::Task['docker:down'].invoke
		Rake::Task['docker:start'].invoke
		Rake::Task['docker:db:create'].invoke
		Rake::Task['docker:db:migrate'].invoke
	end
	
  desc "Start Docker"
  task start: :environment do
		Rake::Task['docker:build'].invoke
		Rake::Task['docker:up'].invoke
  end
  
  desc "Restart Docker"
  task restart: :environment do
		Rake::Task['docker:down'].invoke
		Rake::Task['docker:build'].invoke
		Rake::Task['docker:up'].invoke
  end
  
end
