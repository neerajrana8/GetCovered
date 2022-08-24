source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1.4.1'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.2.3'
# Add union queries to the Rails
gem 'active_record_union', '~> 1.3.0'
# Use Puma as the app server
gem 'puma', '~> 5.6.4'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.11.2'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'authtrail'
gem 'browser'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.9.1', require: false

# NokoGiri
gem 'nokogiri', '>= 1.12.5'

# HTTParty
gem 'httparty'

# recommended by rottmanj
gem 'pry'

# library that prints Ruby objects in full color exposing their internal structure with proper indentation.
gem 'awesome_print'

# rack cors for api access to application
gem 'rack-cors', '>= 1.1.1', require: 'rack/cors'

# attr-encrypted for securing data
gem 'attr_encrypted', '~> 3.1.0'

# Devise for authentication
gem 'devise', '>= 4.8.0'
gem 'devise_invitable', '>= 2.0.5'
gem 'devise_token_auth', '>= 1.2.0'
gem 'omniauth'

# Getting some knowledge
gem 'newrelic_rpm'

# Stripe Gem For Payments
gem 'stripe'
gem 'money'

gem 'plaid'
gem 'rack-timeout'

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
gem 'mailgun-ruby', '~>1.2.5'
gem 'premailer-rails'

gem 'geocoder', '~> 1.6.7'
gem 'StreetAddress', require: 'street_address'

# Colorizing console output to highlight stuffs
gem 'colorize'
gem 'faker'

# AWS SDK
gem 'aws-sdk', '~> 3.1.0'

gem 'active_interaction', '~> 4.0.5'
gem 'mini_magick'
gem 'image_processing', '~> 1.12'

gem 'net-sftp', '~> 3.0.0'

# PDF gems
gem 'wkhtmltopdf-binary', '0.12.6'
gem 'wicked_pdf'
gem "docraptor"
gem "pdf-reader"
gem "prawn"
gem "combine_pdf"

# xlsx file generation
gem 'caxlsx'
# Roo for spreadsheet interaction
gem "roo", git: "https://github.com/roo-rb/roo.git", ref: "868d4ea419cf393c9d8832838d96c82e47116d2f"

# profilers
gem 'memory_profiler', require: false
gem 'ruby-prof', require: false

gem 'addressable'

gem 'klaviyo', :github => 'getcoveredllc/ruby-klaviyo'
gem 'minuteman'

gem 'rack-attack'
gem 'dry-monads'

gem 'rails-i18n', '~> 6.0.0'
gem 'google-apis-gmail_v1'
gem 'rswag-api'

group :local, :development, :test, :test_container do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  #gem 'pry'
  gem 'rspec_junit_formatter'
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'guard-rspec'
  gem 'rails-controller-testing'
  gem 'rspec-rails'
  gem 'rswag-specs'
  gem 'rubocop', '~> 0.63.1', require: false
  gem 'simplecov', require: false
  # RDoc for Documentation
  gem 'rdoc'
  gem 'fuubar'
end

group :development do
  gem 'listen', '< 4.0', '>= 2.7'
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
  #gem 'ruby-debug-ide' #, '0.7.0'
  #gem 'debase' , '0.2.4'
  #gem 'web-console'
  gem 'annotate'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
