# Get Covered 
[![CircleCI](https://circleci.com/gh/getcoveredllc/GetCovered-V2.svg?style=svg&circle-token=0052abe2ebc6773f064fe6582363f1cf58e28dcd)](https://app.circleci.com/pipelines/github/getcoveredllc/GetCovered-V2)

## Setup

### Requirements

* Ruby version according to `.ruby-version` (3.0.1 at the moment)
* Docker
* rvm (https://rvm.io) to manage ruby versions

# Install

* Choose required Ruby version `rvm use 3.0.1`
* Install dependencies `bundle install`
* `export RAILS_ENV=development` // development by default

* This is **bad practice** step, needs to be removed (mentioned in todos and issues):
  * Ask for MASTER_KEY and put it inside config/master.key to decrypto credentials.yml.enc

* Installing containers from scratch `rails docker:install`
* Load seed data `rails docker:development:seed`
* Open in browser http://localhost:3000/v2/health-check, it should return ```{"ok":true,"node":"It's alive!"}```


# Tests

* Run tests in a **test_container**** environment `docker-compose run -e "RAILS_ENV=test_container" web bundle exec rspec`

## TODO's and Issues

* Split environemnt credentials to separate credential files so you don't need to give developers MASTER KEY (rails 6 supports that)
* Setup Swagger properly

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
1) Before installing docker be sure that you already installed ruby, rails, bundler, all gems(bundle install) and DIRENV(optional). 

2) If DIRENV was installed, please check your `.env` and `.envrc` files. It must have RAILS_ENV and RACK_ENV variables set up. 
Please ask colleagues of file example, cause it had specific data for deployment. Easiest way to setup `.envrc` just add `dotenv` directive. 

2a) If you have not installed DIRENV, load the local ENV variables from `.envrc`. The difference between `.envrc` & `.env` is where they run with the former running locally and then later being loaded by Docker. 

3) Install Docker and PostgreSQL server. For MacOS users better to use brew installation.
Once this is complete, the application can be setup by running `RAILS_ENV=development rails docker:install`. 

4) docker-compose build
5) docker-compose up

Possible issues (for MacOS) :
- Bundler v2 incompatibility error.
Resolution:
While installing gems and updating brew bundler can be updated to version 2. If this error happened while `RAILS_ENV=development rails docker:install` 
open Gemfile.lock -> find BUNDLED WITH -> check that it had the same version that initial github file. Update version manually, reinstall bundler & gems.
Run docker-compose build again

- Docker memory allocation failure. 
Resolution:
If you installed Docker desktop just open Docker Client->Preferences->Resources and add more memory.
If app client not installed just add --memory and --memory-swap appropriate values to your docker start command.
Before it please be sure that you had needed space on your machine. Already used space bu docker containers will show `docker stats` command.

- Elastic search container can't create node on current disk. (happened when actual space on your disk less than 85%)
Resolution:
Open docker-compose.yaml -> Find services: elasticsearch: -> add new config & start docker-compose again:
  `environment:
        - discovery.type=single-node
        - cluster.routing.allocation.disk.threshold_enabled=false` 

- DIRENV not working for Iterm2 shell integration
Resolution:
During the one of the steps of DIRENV installation try this ->
Moving the eval `"$(direnv hook bash)"` line after the iterm one. 
Searching for PROMPT_COMMAND= in [https://iterm2.com/shell_integration/bash](https://iterm2.com/shell_integration/bash) shows that they are overriding everything. 
 
- PostgreSQL container can't find socket to connect. This issue not very obvious cause when it happened `docker-compose log` just return:
  `getcovered-v2_worker_1 exited with code 1
   getcovered-v2_web_1 exited with code 1`
Inspecting log above this message can appear: 
web_1            | standard_init_linux.go:211: exec user process caused "no such file or directory" 
Resolution:
There are two ways of fixing it:
First of all check with `sudo netstat -ln | grep 5432` where postgres listening right now. It will be /tmp or /var (depended of how postgres was installed and os version) 
Easy one -> open database.yaml -> find default: and add at the end if previous command shows /tmp and change to /var path at other way
  `socket: /tmp/.s.PGSQL.5432` 
Harder one -> just create a soft link like `ln -s /tmp/.s.PGSQL.5432 /var/run/postgresql/.s.PGSQL.5432` but be sure that you had created /var/run/postgresql/ folders at first. 
or in other way of pathes depending on what previous command showed.

- PostgreSQL can't find user postgres or password invalid. It happened if during installation you didn't setup super user for PostgreSQL - it just create super user with name of your current os user.
Resolution:

- Cannot load 'Rails.application.database_configuration': (NoMethodError)undefined method `[]' for nil:NilClass
Resolution:
Please be sure that your git and code redactor used LF not CRLF encoding identation. In other case it caused erb isssue with parsing code in yaml files like database.yaml 

- <i><b>M1 Mac</b>: Containers fail to build due to `nokogiri` / other gem issues.</i>  
Solution:
Default platform set for building docker containers may be lame, try building `linux/amd64` containers instead. Either run `docker-compose up --build --platform linux/amd64` or set it in `docker-compose.yml` explicitly.

- <i><b>M1 Mac</b>: `Function not implemented - Failed to initialize inotify (Errno::ENOSYS)`</i>  
Solution: https://github.com/evilmartians/terraforming-rails/issues/34#issuecomment-872021786

`git config --global core.autocrlf input`

Additional commands for managing the API on docker locally include: 
* `rails docker:down` Takes down all docker-compose services
* `rails docker:build` Builds all docker-compose services
* `rails docker:up` Starts all docker-compose services
* `rails docker:db:create` Creates PG database in docker-compose service
* `rails docker:db:migrate` Migrates PG database in docker-compose service
* `rails docker:install` Sets up all docker-compose services and migrates the database to latest version
* `rails docker:start` Builds and Starts all docker-compose services
* `rails docker:restart` Removes all docker-compose services, builds then re-start them under force-recreate

Before running these commands double check that you have .env file with set RAILS_ENV
To make commands work you still need to add RAILS_ENV variable like  `RAILS_ENV=development rails docker:down` (usually RAILS_ENV=development but can be other for your needs)
If you have an issue with DB such as (cannot translate host db) you can ask for tmp/db dir from current devs as fast solution

6) If all started and no errors showed open `http://localhost:3000/v2/health-check` (or change port to any other if you don't use standart one)
if you see message '{"ok":true,"node":"It's alive!"}' Congratulations! Backend alive.

7) Setup test environment database with instructions below. After that try run tests on test_container and be sure that they started to work. 
It important to understand that for tests in test env was imported only basic seeds (can be checked in docker.rake -> 'Seed test DB' task) 
There is command `docker-compose run -e "RAILS_ENV=test_container" web bundle exec rake db:seed section=setup` which import only section=setup from seeds. It's okay for tests but not full for client apps working properly.

8) After setup of clients apps to make them work with api please run:
`RAILS_ENV=development bundle exec rake docker:development:seed`
  
9) After successful finish you can run client app with `ng serve` and be sure that you can see pages. 
  
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

##### Using data migrations

Currently we split schema migrations and data migrations to keep track of changes on prod. Please each time when you understand that there is a need to change any field value on prod or dev create data migration and run deploy with steps decribed below. For separating migrations we use gem https://github.com/ilyakatz/data-migrate 
1) create data migration with command ```  rails g data_migration add_this_to_that ``` 
2) find your newly created migration in db/data folder
3) add any data updates which need to be applied (don't forget about up and down methods to make it revertable)
4) run ``` rake data:migrate ``` and check how it goes. if needed use ``` rake data:rollback  ``` to revert data migration and fix if needed 
5) after successful migration db/data_schema.rb file will be updated with new version 
6) commit changes and after deploy it will be automatically applied after successful schema migration (``` rake db:migrate ``` ). if schema migration failed data migration will not be applied. 
