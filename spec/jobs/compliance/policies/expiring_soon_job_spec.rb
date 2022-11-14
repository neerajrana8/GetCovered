require 'rails_helper'

RSpec.describe Compliance::Policies::ExpiringSoonJob, type: :job do
  pending "add some examples to (or delete) #{__FILE__}"

  it 'should sent notification for policy which expected to expire in 7 days' do
    user = FactoryBot.create(:user)
    policy_type = PolicyType.find_by_title('Residential')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    branding_profile = FactoryBot.create(:branding_profile, profileable: account)
    carrier = Carrier.first
    carrier.agencies << [agency]

    policy = FactoryBot.build(:policy, account: account, agency: agency, carrier: carrier,
                              policy_in_system: true,
                              policy_type: policy_type,
                              status: 'BOUND',
                              auto_pay: false,
                              expiration_date: DateTime.current.to_date + 7.days,
                              billing_enabled: true)
    FactoryBot.create(:policy_user, user: user, policy: policy)

    expect { Compliance::Policies::ExpiringSoonJob.perform_now }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
end
