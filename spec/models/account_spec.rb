# frozen_string_literal: true

RSpec.describe Account, elasticsearch: true, type: :model do
  it 'Account Get Covered should be indexed' do
    # already created in setup seeds FactoryBot.create(:account)
    # refresh the index 
    Account.__elasticsearch__.refresh_index!
    # verify your model was indexed
    expect(Account.search('Get Covered').records.length).to eq(1)
  end

  it 'Account Test should not be indexed' do
    # refresh the index 
    Account.__elasticsearch__.refresh_index!
    # verify your model was indexed
    expect(Account.search('Test').records.length).to eq(0)
  end
end
