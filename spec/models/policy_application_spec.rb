# frozen_string_literal: true

RSpec.describe PolicyApplication, type: :model do
  it 'cannot add Insurable without address' do
    pending('should be fixed')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy_application = FactoryBot.create(:policy_application, carrier: carrier, agency: agency, account: account)
    insurable = FactoryBot.create(:insurable)
    insurable.addresses = []
    insurable.account = policy_application.account
    insurable.save
    
    catch(:no_address) do
      policy_application.insurables << insurable
    end
    
    expect(policy_application.insurables).to be_empty

    insurable.addresses << FactoryBot.create(:address)
    policy_application.insurables << insurable
    expect(policy_application.insurables).to_not be_empty
  end

  it 'insurables must belong to the same account' do
    pending('should be fixed')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy_application = FactoryBot.create(:policy_application, carrier: carrier, agency: agency, account: account)
    insurable = FactoryBot.create(:insurable)
    insurable.account = FactoryBot.create(:account)
    insurable.addresses << FactoryBot.create(:address)
    insurable.save
    begin
      policy_application.insurables << insurable
    rescue ActiveRecord::RecordInvalid
    end
    expect(policy_application.insurables).to be_empty
  end

end
