# frozen_string_literal: true

RSpec.describe Agency, elasticsearch: true, type: :model do
  it 'Agency Get Covered should be indexed' do
    FactoryBot.create(:agency)
    Agency.__elasticsearch__.refresh_index!
    expect(Agency.search('Get Covered').records.length).to eq(1)
  end

  it 'Agency Test should not be indexed' do
    FactoryBot.create(:agency)
    Agency.__elasticsearch__.refresh_index!
    expect(Agency.search('Test').records.length).to eq(0)
  end
end
