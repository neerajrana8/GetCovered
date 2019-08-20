require 'rails_helper'

RSpec.describe Account, elasticsearch: true, :type => :model do
  it 'Account Get Covered should be indexed' do
    FactoryBot.create(:account)
    # refresh the index 
    Account.__elasticsearch__.refresh_index!
    # verify your model was indexed
    expect(Account.search('Get Covered').records.length).to eq(1)
  end

  it 'Account Test should not be indexed' do
    FactoryBot.create(:account)
    # refresh the index 
    Account.__elasticsearch__.refresh_index!
    # verify your model was indexed
    expect(Account.search('Test').records.length).to eq(0)
  end
end
