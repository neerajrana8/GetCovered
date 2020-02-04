require 'rake'

namespace :seed_insurables do
  task run_seed: :environment do
    Rake::Task['seed_insurables:seed_accounts'].invoke
  	Rake::Task['seed_insurables:seed_insurables'].invoke
  end
  desc 'Create 10,000 insurables'
  task seed_insurables: :environment do
    test_agency = Agency.find_by(title: "Agency with seed test data")
    return if test_agency.nil?
    
    account = test_agency.accounts.first
    1.upto(3) do |i|
      insurable_type = InsurableType.find(i)
      10000.times do |i|
        account.insurables.create(
          title: Faker::Address.community, 
          insurable_type: insurable_type, 
          enabled: true, 
          category: 'property',
          addresses_attributes: [ 
            {
              street_number: Faker::Address.building_number,
              street_name: Faker::Address.street_name,
              city: Faker::Address.city,
              state: Faker::Address.state_abbr,
              zip_code: Faker::Address.zip_code,
              primary: true
            }
          ]
        )	
      end
    end
  end
  desc 'Create 10,000 accounts'
  task seed_accounts: :environment do
    test_agency = Agency.create(title: "Agency with seed test data")
    10000.times do |i|
      test_agency.accounts.create(
        title: Faker::Company.name,
        enabled: true, 
        whitelabel: true, 
        tos_accepted: true, 
        tos_accepted_at: Time.current, 
        verified: true, 
        stripe_id: nil
      )
    end
  end
end
