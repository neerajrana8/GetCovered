# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] = %w[test test_container].include?(ENV['RAILS_ENV']) ? ENV['RAILS_ENV'] : 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
require 'devise'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
RSpec.configure do |config|
  # Devise
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Helpers
  config.include ModelParams
  
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  
  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  
  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!
  
  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
  
  config.before :example, perform_enqueued: true do
    @old_perform_enqueued_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_jobs
    @old_perform_enqueued_at_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
  end
  
  config.after :example, perform_enqueued: true do
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = @old_perform_enqueued_jobs
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = @old_perform_enqueued_at_jobs
  end
  
  
  # Clean database
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation,
                               except: %w[lease_types policy_types insurable_types carriers
                                          lease_type_policy_types lease_type_insurable_types
                                          carrier_policy_types carrier_insurable_types])
  end
  
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
  
  
  # Stop elasticsearch cluster after test run
  config.after :suite do
    ActiveRecord::Base.descendants.each do |model|
      if model.respond_to?(:__elasticsearch__)
        begin
          model.__elasticsearch__.delete_index!
        rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
          # This kills "Index does not exist" errors being written to console
          # by this: https://github.com/elastic/elasticsearch-rails/blob/738c63efacc167b6e8faae3b01a1a0135cfc8bbb/elasticsearch-model/lib/elasticsearch/model/indexing.rb#L268
        rescue => e
          STDERR.puts "There was an error removing the elasticsearch index for #{model.name}: #{e.inspect}"
        end
      end
    end
  end
end
