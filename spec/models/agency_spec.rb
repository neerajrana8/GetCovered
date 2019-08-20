require 'rails_helper'

RSpec.describe Agency, elasticsearch: true, :type => :model do
  it 'Agency Get Covered should be indexed' do
    FactoryBot.create(:agency)
    # refresh the index 
    Agency.__elasticsearch__.refresh_index!
    # verify your model was indexed
    expect(Agency.search('Get Covered').records.length).to eq(1)
  end

  it 'Agency Test should not be indexed' do
    FactoryBot.create(:agency)
    # refresh the index 
    Agency.__elasticsearch__.refresh_index!
    # verify your model was indexed
    expect(Agency.search('Test').records.length).to eq(0)
  end
end
