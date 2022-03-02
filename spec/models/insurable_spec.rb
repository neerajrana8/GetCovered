require 'rails_helper'

RSpec.describe Insurable, elasticsearch: true, type:  :model do
  it 'should belong to same Account if it has insurable parent' do
    account = FactoryBot.create(:account)
    insurable = FactoryBot.create(:insurable)
    child_insurable = insurable.insurables.create(
      title: 'New test insurable',
      account: account,
      insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS.first
    )
    expect(child_insurable).to_not be_valid
    child_insurable.errors[:account].should include('must belong to same account as parent')
    
    child_insurable.account = insurable.account
    child_insurable.save
    expect(child_insurable).to be_valid
  end
end
