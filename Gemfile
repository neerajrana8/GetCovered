source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.5.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.2.1'
# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Use Puma as the app server
gem 'puma', '~> 3.11'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'


# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# NokoGiri
gem 'nokogiri'

# HTTParty
gem 'httparty'

# recommended by rottmanj
gem 'pry'

# rack cors for api access to application
gem 'rack-cors', :require => 'rack/cors'

# attr-encrypted for securing data
gem "attr_encrypted", "~> 3.0.0"

# Devise for authentication
gem 'devise_token_auth'
gem 'omniauth'
gem 'devise_invitable', '~> 1.7.0'

# Getting some knowledge
gem 'newrelic_rpm'

# Stripe Gem For Payments
gem 'stripe'

# Sidekiq for background job processing
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Timezone for automatic timezones
gem 'timezone', '~> 1.0'

# Twillo for Chats :)
gem 'twilio-ruby', '~> 4.11.1'

# Kaminari for pagination
gem 'kaminari'

# Mailing
gem 'mailgun-ruby', '~>1.1.6'
gem 'premailer-rails'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'faker'
  gem "factory_bot_rails"
  gem 'rspec-rails'
  gem 'rails-controller-testing'
  gem 'guard-rspec'
  gem 'database_cleaner'
  gem 'rubocop', '~> 0.48.1', require: false
  # RDoc for Documentation
  gem 'rdoc'  
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
