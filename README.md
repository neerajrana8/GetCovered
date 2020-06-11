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

