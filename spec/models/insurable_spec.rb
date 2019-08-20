require 'rails_helper'

RSpec.describe Insurable, elasticsearch: true, :type => :model do
  it 'Insurable Test title should be indexed' do
    FactoryBot.create(:insurable)
    Insurable.__elasticsearch__.refresh_index!
    expect(Insurable.search('Test title').records.length).to eq(1)
  end

  it 'Insurable Wrong Name should not be indexed' do
    FactoryBot.create(:insurable)
    Insurable.__elasticsearch__.refresh_index!
    expect(Insurable.search('Wrong Name').records.length).to eq(0)
  end
end
