# frozen_string_literal: true

# == Schema Information
#
# Table name: agencies
#
#  id                      :bigint           not null, primary key
#  title                   :string
#  slug                    :string
#  call_sign               :string
#  enabled                 :boolean          default(FALSE), not null
#  whitelabel              :boolean          default(FALSE), not null
#  tos_accepted            :boolean          default(FALSE), not null
#  tos_accepted_at         :datetime
#  tos_acceptance_ip       :string
#  verified                :boolean          default(FALSE), not null
#  stripe_id               :string
#  master_agency           :boolean          default(FALSE), not null
#  contact_info            :jsonb
#  settings                :jsonb
#  agency_id               :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  staff_id                :bigint
#  integration_designation :string
#  producer_code           :string
#  carrier_preferences     :jsonb            not null
#
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
