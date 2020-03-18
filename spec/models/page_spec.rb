require 'rails_helper'

RSpec.describe Page, :type => :model do
  subject {
    described_class.new(title: "Anything",
                        content: "Lorem ipsum",
                        agency: FactoryBot.create(:agency),
                        branding_profile: FactoryBot.create(:branding_profile))
  }

  it "is valid with valid attributes" do
    expect(subject).to be_valid
  end

  it "is not valid without a agency" do
    subject.agency = nil
    expect(subject).to_not be_valid
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
