source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.5.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.2.2.1'
# Use postgresql as the database for Active Record
gem 'pg', '>= 0.18', '< 2.0'
# Add union queries to the Rails
gem 'active_record_union'
# Use Puma as the app server
gem 'puma', '~> 3.12.6'
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

gem 'authtrail'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

# NokoGiri
gem 'nokogiri', '>= 1.10.8'

# HTTParty
gem 'httparty'

# recommended by rottmanj
gem 'pry'

# library that prints Ruby objects in full color exposing their internal structure with proper indentation.
gem 'awesome_print'

# rack cors for api access to application
gem 'rack-cors', '>= 1.0.5', require: 'rack/cors'

# attr-encrypted for securing data
gem 'attr_encrypted', '~> 3.0.0'

# Devise for authentication
gem 'devise', '>= 4.7.1'
gem 'devise_invitable', '>= 2.0.1'
gem 'devise_token_auth', '>= 1.1.3'
gem 'omniauth'

# Getting some knowledge
gem 'newrelic_rpm'

# Stripe Gem For Payments
gem 'stripe'
gem 'money'

gem 'plaid'


# Sidekiq for background job processing
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Timezone for automatic timezones
gem 'timezone', '~> 1.0'

# Twillo for Chats :)
gem 'twilio-ruby', '~> 4.11.1'

# Kaminari for pagination
gem 'kaminari', '>= 1.2.1'

# Mailing
gem 'mailgun-ruby', '~>1.1.6'
gem 'premailer-rails'

gem 'geocoder', '~> 1.6.1'
gem 'StreetAddress', require: 'street_address'

gem 'elasticsearch-model', github: 'elastic/elasticsearch-rails', branch: '5.x'
gem 'elasticsearch-rails', github: 'elastic/elasticsearch-rails', branch: '5.x'

# Colorizing console output to highlight stuffs
gem 'colorize'
gem 'faker'

# AWS SDK
gem 'aws-sdk', '~> 3'

gem 'active_interaction', '~> 3.7'
gem 'mini_magick'

gem 'net-sftp', '~> 2.1', '>= 2.1.2'

# PDF gems
gem 'wkhtmltopdf-binary'
gem 'wicked_pdf'
gem "docraptor"

# xlsx file generation
gem 'caxlsx'
# Roo for spreadsheet interaction
gem 'roo', '~> 2.8.0'

# profilers
gem 'memory_profiler', require: false
gem 'ruby-prof', require: false

gem 'addressable'
gem 'analytics-ruby', '~> 2.0.0', :require => 'segment/analytics'
gem 'klaviyo'

group :development, :test, :test_container do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'pry'
  gem 'rspec_junit_formatter'
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'guard-rspec'
  gem 'rails-controller-testing'
  gem 'rspec-rails'
  gem 'rubocop', '~> 0.63.1', require: false
  gem 'simplecov', require: false
  # RDoc for Documentation
  gem 'rdoc'
  gem 'fuubar'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'rails-erd'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  #need to open letters in dev_mode
  gem 'letter_opener'
  gem 'letter_opener_web', '~> 1.0'
  gem 'guard'
  gem 'guard-shell'
  #rubymine specific debug gems
    # gem 'ruby-debug-ide'
    # gem 'debase'
    # gem 'web-console'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
