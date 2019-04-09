require 'rake'

namespace :getcovered do

  desc "Install Locally"
  task install: :environment do
  		env = "local"
    system("rails db:create RAILS_ENV=#{ env } && rails db:migrate RAILS_ENV=#{ env }")
		Rake::Task['docker:install'].invoke
  end
  
end
