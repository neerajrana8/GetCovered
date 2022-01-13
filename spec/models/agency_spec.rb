# frozen_string_literal: true

RSpec.describe Agency, elasticsearch: true, type: :model do
  it 'should allow more then one branding profile' do
    agency = FactoryBot.create(:agency)
    agency.branding_profiles.create(url: 'new_agency.com')
    expect(agency.branding_profiles.count).to eq(1)
    new_branding = agency.branding_profiles.create(url: 'new_agency2.com')
    expect(new_branding.persisted?).to eq(true)
    expect(agency.branding_profiles.count).to eq(2)
  end
end
