require 'rails_helper'

RSpec.describe Address, elasticsearch: true, :type => :model do
  it 'Address in Los Angeles should be indexed' do
    FactoryBot.create(:address, city: 'Los Angeles')
    Address.__elasticsearch__.refresh_index!
    expect(Address.search('Los Angeles').records.length).to eq(1)
  end

  it 'Address in Moscow should not be indexed' do
    FactoryBot.create(:address, city: 'Los Angeles')
    Address.__elasticsearch__.refresh_index!
    expect(Address.search('Moscow').records.length).to eq(0)
  end
end
