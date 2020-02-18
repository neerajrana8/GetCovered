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

  desc "Rails console"
  task console: :environment do
    system("docker-compose run web rails c")
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

  namespace :tests do
    desc "Create test DB"
    task create_db: :environment do
      system("docker-compose run -e \"RAILS_ENV=test\" web rails db:create")
    end

    desc "Migrate test DB"
    task migrate_db: :environment do
      system("docker-compose run -e \"RAILS_ENV=test\" web rails db:migrate")
    end

    desc "Run rspec"
    task run_rspec: :environment do
      system("docker-compose run -e \"RAILS_ENV=test\" web bundle exec rspec")
    end

    desc "Run all steps for the tests"
    task run: :environment do
      Rake::Task['docker:tests:create_db'].invoke
      Rake::Task['docker:tests:migrate_db'].invoke
      Rake::Task['docker:tests:run_rspec'].invoke
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
