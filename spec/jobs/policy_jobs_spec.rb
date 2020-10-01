# frozen_string_literal: true

require 'rails_helper'

describe 'Policy jobs spec', type: :request do

  it 'should generate payments for enabled next payment date policies' do
    pending('should be fixed or removed, because we do not use this job')
    user = FactoryBot.create(:user)
    policy_type = PolicyType.find_by_title('Residential')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]

    policy = FactoryBot.build(:policy, account: account, agency: agency, carrier: carrier,
                              policy_in_system: true,
                              policy_type: policy_type,
                              status: 'QUOTE_ACCEPTED',
                              auto_pay: false,
                              billing_enabled: true)
    FactoryBot.create(:policy_user, user: user, policy: policy)
    invoice = Invoice.new do |i|
      i.payer = user
      i.status = 'missed'
      i.number = Time.now.to_i
      i.due_date = 1.day.ago
      i.available_date = 1.day.ago
      i.invoiceable = policy
    end
    invoice.save!

    expect { PolicyBillingCycleCheckJob.perform_now }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end

  it 'should perform queued refunds' do
    pending('should be fixed or removed, because we do not use this job')
    user = FactoryBot.create(:user)
    policy_type = PolicyType.find_by_title('Residential')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy = FactoryBot.build(:policy, account: account, agency: agency, carrier: carrier)
    policy.policy_in_system = true
    policy.policy_type = policy_type
    policy.billing_dispute_status = 'AWAITING_POSTDISPUTE_PROCESSING'
    policy.billing_enabled = true
    policy.auto_pay = false
    policy.save!
    PolicyPostdisputeRefundJob.perform_now
  end

  it 'should perform queued invitation send and status update after registration of residential policy' do
    PolicyUser.any_instance.stub(:set_first_as_primary).and_return(true)
    PolicyUser.any_instance.stub(:set_account_user).and_return(true)

    policy_application = FactoryBot.create(:policy_application_with_policy)
    policy_application.build_from_carrier_policy_type
    policy_user = policy_application.policy.policy_users.last

    #need to be sure that no account user was created in mocks before
    expect(AccountUser.where(user: policy_user, account: policy_application.account)).to eq([])

    acc_user = AccountUser.create!(user: policy_user.user, account: policy_application.account)

    PolicyQuoteStartBillingJob.perform_now(policy: policy_application.policy, issue: 'qbe_issue_policy' )

    expect(acc_user.reload.status).to eq("enabled")

  end
end
