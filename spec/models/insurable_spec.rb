require 'rails_helper'

RSpec.describe Insurable, elasticsearch: true, type:  :model do
  it 'Insurable Test title should be indexed' do
    FactoryBot.create(:insurable)
    Insurable.__elasticsearch__.refresh_index!
    expect(Insurable.search('1').records.length).to eq(1)
  end

  it 'Insurable Wrong Name should not be indexed' do
    FactoryBot.create(:insurable)
    Insurable.__elasticsearch__.refresh_index!
    expect(Insurable.search('Wrong Name').records.length).to eq(0)
  end

  it 'should belong to same Account if it has insurable parent' do
    account = FactoryBot.create(:account)
    insurable = FactoryBot.create(:insurable)
    child_insurable = insurable.insurables.create(
      title: 'New test insurable',
      account: account,
      insurable_type: FactoryBot.create(:insurable_type)
    )
    expect(child_insurable).to_not be_valid
    child_insurable.errors[:account].should include('must belong to same account as parent')
    
    child_insurable.account = insurable.account
    child_insurable.save
    expect(child_insurable).to be_valid
  end
end
