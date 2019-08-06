# frozen_string_literal: true

require 'rails_helper'

describe 'Policy jobs spec', type: :request do
  
  it 'should generate payments for enabled next payment date policies' do
    user = FactoryBot.create(:user)
    primary_policy_user = FactoryBot.create(:policy_user)
    policy_type = FactoryBot.create(:policy_type)
    policy = FactoryBot.build(:policy)
    policy.policy_in_system = true
    policy.policy_type = policy_type
    policy.status = 'QUOTE_ACCEPTED'
    policy.primary_policy_user = primary_policy_user
    policy.billing_enabled = true
    policy.auto_pay = false
    policy.save!
    invoice = Invoice.new do |i|
      i.user = user
      i.status = 'missed'
      i.number = Time.now.to_i
      i.due_date = 1.day.ago
      i.available_date = 1.day.ago
      i.policy = policy
    end
    invoice.save!

    expect { PolicyBillingCycleCheckJob.perform_now }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end
  
  it 'should perform queued refunds' do
    user = FactoryBot.create(:user)
    policy_type = FactoryBot.create(:policy_type)
    policy = FactoryBot.build(:policy)
    policy.policy_in_system = true
    policy.policy_type = policy_type
    policy.billing_dispute_status = 'AWATING_POSTDISPUTE_PROCESSING'
    policy.billing_enabled = true
    policy.auto_pay = false
    policy.save!
    PolicyPostdisputeRefundJob.perform_now
  end
end