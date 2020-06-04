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
    desc 'Drop test DB'
    task drop: :environment do
      system('docker-compose run -e "RAILS_ENV=test_container" web bundle exec rake db:drop')
    end

    desc 'Create test DB'
    task create: :environment do
      system('docker-compose run -e "RAILS_ENV=test_container" web bundle exec rake db:create')
    end

    desc 'Migrate test DB'
    task migrate: :environment do
      system('docker-compose run -e "RAILS_ENV=test_container" web bundle exec rake db:migrate')
    end

    desc 'Seed test DB'
    task seed: :environment do
      system('docker-compose run -e "RAILS_ENV=test_container" web bundle exec rake db:seed section=setup')
    end

    desc 'Run rspec'
    task rspec: :environment do
      system('docker-compose run -e "RAILS_ENV=test_container" web bundle exec rspec')
    end

    desc 'Recreate database and seed from the setup'
    task :recreate_database do
      Rake::Task['docker:tests:drop'].invoke
      Rake::Task['docker:tests:create'].invoke
      Rake::Task['docker:tests:migrate'].invoke
      Rake::Task['docker:tests:seed'].invoke
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
