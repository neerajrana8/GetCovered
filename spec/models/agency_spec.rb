# frozen_string_literal: true

RSpec.describe Agency, elasticsearch: true, type: :model do
  it 'Agency Get Covered should be indexed' do
    pending('floating bug only on the circleci')
    FactoryBot.create(:agency)
    Agency.__elasticsearch__.refresh_index!
    expect(Agency.search('Get Covered').records.length).to eq(1)
  end
  
  it 'Agency Test should not be indexed' do
    FactoryBot.create(:agency)
    Agency.__elasticsearch__.refresh_index!
    expect(Agency.search('Test').records.length).to eq(0)
  end
  
  it 'should allow more then one branding profile' do
    agency = FactoryBot.create(:agency)
    agency.branding_profiles.create(title: 'new', url: 'new_agency.com')
    expect(agency.branding_profiles.count).to eq(1)
    new_branding = agency.branding_profiles.create(title: 'new2', url: 'new_agency2.com')
    expect(new_branding.persisted?).to eq(true)
    expect(agency.branding_profiles.count).to eq(2)
  end
end
