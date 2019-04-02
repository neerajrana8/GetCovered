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
  
  desc "Migrate Docker"
	task migrate: :environment do
		system("docker-compose run web rails db:migrate")
	end
	
	desc "Install from Docker"
	task install: :environment do
		Rake::Task['docker:down'].invoke
		Rake::Task['docker:build'].invoke
		system("docker-compose run web rails db:create")
		Rake::Task['docker:migrate'].invoke
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
