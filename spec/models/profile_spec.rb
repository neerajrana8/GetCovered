# frozen_string_literal: true

RSpec.describe Profile, elasticsearch: true, type: :model do
  it 'Profile Test should be indexed' do
    FactoryBot.create(:profile, first_name: 'Test')
    Profile.__elasticsearch__.refresh_index!
    expect(Profile.search('Test').records.length).to eq(1)
  end

  it 'Profile Wrong should not be indexed' do
    FactoryBot.create(:profile, first_name: 'Test')
    Profile.__elasticsearch__.refresh_index!
    expect(Profile.search('Wrong').records.length).to eq(0)
  end
end
