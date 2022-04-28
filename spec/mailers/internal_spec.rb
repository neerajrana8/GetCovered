require "rails_helper"

RSpec.describe InternalMailer, type: :mailer do
  describe "error" do
    let(:mail) { InternalMailer.error }

    it "renders the headers" do
      expect(mail.subject).to eq("Error")
      expect(mail.to).to eq(["to@example.org"])
      expect(mail.from).to eq(["from@example.com"])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

end
