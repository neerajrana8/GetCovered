require 'rails_helper'

RSpec.describe Carrier, elasticsearch: true, :type => :model do
  it 'Carrier Test Carrier should be indexed' do
    FactoryBot.create(:carrier)
    Carrier.__elasticsearch__.refresh_index!
    expect(Carrier.search('Test Carrier').records.length).to eq(1)
  end

  it 'Carrier Wrong Name should not be indexed' do
    FactoryBot.create(:carrier)
    Carrier.__elasticsearch__.refresh_index!
    expect(Carrier.search('Wrong Name').records.length).to eq(0)
  end
end
