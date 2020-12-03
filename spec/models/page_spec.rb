require 'rails_helper'

RSpec.describe Page, :type => :model do
  subject {
    agency = FactoryBot.create(:agency)
    agency.update(id: 1)
    branding_profile = FactoryBot.create(:branding_profile)
    branding_profile.update(profileable: agency)
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

  it "must sanitize script tag" do
    subject.content = "<p>Lorem ipsum <script>dangerous javascript</script></p>"
    expect(subject.content).to include "<script>dangerous javascript</script>"
    subject.save
    expect(subject.content).not_to include "<script>dangerous javascript</script>"
  end
end
