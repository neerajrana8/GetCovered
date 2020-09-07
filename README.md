# Get Covered 
[![CircleCI](https://circleci.com/gh/getcoveredllc/GetCovered-V2.svg?style=svg&circle-token=0052abe2ebc6773f064fe6582363f1cf58e28dcd)](https://app.circleci.com/pipelines/github/getcoveredllc/GetCovered-V2)

#### API Layer
#### Version 2.0.0/development

Created: 11/21/2017
Updated: 04/12/2019

#### Requirements
* Ruby 2.5.1+
* Rails 5.2.2.1
* [DIRENV](https://github.com/direnv/direnv) (optional)
* Docker
* Docker-compose
* PostgreSQL 9+ (10+ preferably)

#### Installation (hopefully)
Before installing docker and a local pg server should be running and all gems should be installed.  If you have not installed DIRENV, load the local ENV variables from `.envrc`, the difference between `.envrc` & `.env` is where they run with the former running locally and the latter being loaded by Docker.  Once this is complete, the application can be setup by running `rails getcovered:install`.  Additional commands for managing the API on docker locally include: 
Before running these commands make sure that you should have .env file with set RAILS_ENV
These commands should be run with set RAILS_ENV env variable (usually RAILS_ENV=development)
If you have an issue with DB such as (cannot translate host db) you can ask for tmp/db dir from current devs as fast solution
* `rails docker:down` Takes down all docker-compose services
* `rails docker:build` Builds all docker-compose services
* `rails docker:up` Starts all docker-compose services
* `rails docker:db:create` Creates PG database in docker-compose service
* `rails docker:db:migrate` Migrates PG database in docker-compose service
* `rails docker:install` Sets up all docker-compose services and migrates the database to latest version
* `rails docker:start` Builds and Starts all docker-compose services
* `rails docker:restart` Removes all docker-compose services, builds then re-start them under force-recreate

#### Tests
There are two ways to launch tests: locally and in a container.

##### Locally
Before all you should prepare the test environment: 
* `RAILS_ENV=test bundle exec rake db:drop` - drop database if exists
* `RAILS_ENV=test bundle exec rake db:create` - create test database
* `RAILS_ENV=test bundle exec rake db:migrate` - run migrations
* `RAILS_ENV=test bundle exec rake db:seed section=setup` - create default tables

After it you can run tests using `RAILS_ENV=test bundle exec rspec` command.

##### Using Docker Compose
Before it you should run `docker-compose up` because the all listed below are started by using the `docker-composer exec`.

There are two main commands:   
* `RAILS_ENV=test_container bundle exec rake docker:tests:recreate_database` - recreates a database, runs migrations,
and seeds by data from the db/seeds/setup.rb
* `RAILS_ENV=test_container bundle exec rake docker:tests:rspec` - run all tests

If you want to launch a certain test use the next form: 

`docker-compose exec -e "RAILS_ENV=test_container" web bundle exec rspec 'spec/requests/leases/bulk_creation_spec.rb'`

##### Using letter-opener (for MacOS)

1) Add to your gemfile & install bundle
`gem 'letter_opener'
 gem 'letter_opener_web', '~> 1.0'
 gem 'guard'
 gem 'guard-shell'` 

2) Open development.rb and check that your action_mailer configs as below 
`config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
config.action_mailer.default_options  = {
   from:  "no-reply <some@test.com>"
}
-- if standart port already in use:
 config.action_mailer.default_url_options = { host: 'localhost', port: 3001 }`
 
3) Open config/routes.rb and add
 `mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?`
 
4) Open docker-compose.yml and check that at web: volumes looks like below:

 `volumes:
    - .:/getcovered
    - ./tmp/letter_opener:/getcovered/tmp/letter_opener/`

4*) Sometimes its more suitable to run sidekiq workers synchronous. To make if like that open development.rb and add: 
`require 'sidekiq/testing/inline'`

5) docker-compose build & docker-compose up

After that you can open `localhost:3000/letter_opener` and all sent emails will be available for testing. 

Next steps needed if you want automatically open email files in browser (please don't forget to delete old emails from tmp folder, because each  new email will trigger all of them to open)
6) Open your terminal in folder with project and run
  `bundle exec guard init`
  
7) Open generated file Guard file and add (ex. `subl Guardfile`):
  `guard :shell do
     watch(%r{^tmp/letter_opener/*/.+rich\.html}) do |modified_files|
       `open #{modified_files[0]}`
      end
    end` 

8) run in terminal `guard`
You must see message : "- INFO - Guard is now watching at '/YOU_PROJECT_DIRECTORY/GetCovered-V2'"
Try to send email and check it in your default browser

## Errors 
All new errors and if possible old must use the next format:

```ruby
{
  error: :short_error_tag, # required
  message: "Long and meaningful message that can be showed to a user", # optional
  payload: @user.errors || ['your', :custom, {object: nil}] # optional
}
```

* **error** - just a tag to simplify recognize an error in code. _(symbol, snake_case, required)_;
* message - Human-readable message that contains information about what was happened. This message 
can be used in the pop-ups and/or just to clarify an error. _(string, free format, optional)_
* payload - object that can store absolutely anything. Tne most common usage is to store errors from 
active record models, parser, external services. _(any object, free format, optional)_

There is a method in the `application_controller` that wraps this hash - `standard_error`. Examples:
```ruby
#render full error
render(
  json: standard_error(:something_went_wrong, 'Everything goes wrong', @user.errors).to_json, 
  status: 401
)
#render without payload
render(
  json: standard_error(:something_went_wrong, 'Everything goes wrong').to_json, 
  status: 401
)
#render without message
render(
  json: standard_error(:something_went_wrong, nil, @user.errors).to_json, 
  status: 401
)
```
