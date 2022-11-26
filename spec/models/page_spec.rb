# == Schema Information
#
# Table name: pages
#
#  id                  :bigint           not null, primary key
#  content             :text
#  title               :string
#  agency_id           :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  branding_profile_id :bigint
#  styles              :jsonb
#
require 'rails_helper'

RSpec.describe Page, :type => :model do
  subject {
    agency = Agency.find(1)
    branding_profile = FactoryBot.create(:branding_profile, profileable: agency)
    described_class.new(title: "Anything",
                        content: "Lorem ipsum",
                        branding_profile: branding_profile)
  }

  it "is valid with valid attributes" do
    expect(subject).to be_valid
  end

  it "is valid without an agency" do
    subject.agency = nil
    expect(subject).to be_valid
  end

  it "is not valid without a branding_profile" do
    subject.branding_profile = nil
    expect(subject).to_not be_valid
  end
end
