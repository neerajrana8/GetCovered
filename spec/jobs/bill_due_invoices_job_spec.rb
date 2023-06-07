# frozen_string_literal: true

require 'rails_helper'

describe 'Bill due invoice spec', type: :request do
  before(:each) do
    user = FactoryBot.create(:user)
    policy_type = PolicyType.find_by_title('Residential')
    agency = FactoryBot.create(:agency)
    account = FactoryBot.create(:account, agency: agency)
    carrier = Carrier.first
    carrier.agencies << [agency]
    policy = FactoryBot.build(:policy, agency: agency)
    policy.policy_in_system = true
    policy.policy_type = policy_type
    policy.billing_enabled = true
    policy.auto_pay = true
    policy.carrier = carrier
    policy.agency = agency
    policy.account = account
    policy.status = 'BOUND'
    policy.save!
    
    @policy = policy
    
    @invoice = FactoryBot.create(:invoice, invoiceable: policy, due_date: Time.current.to_date, available_date: Time.current.to_date - 1.day, status: 'available')
    @invoice.payer.attach_payment_source("tok_visa", true)

  end
  
  it 'should pay invoices' do 
    policy_ids = Policy.select(:id).policy_in_system(true).current.where(auto_pay: true).pluck(:id)
    expect(policy_ids.include?(@policy.id)).to eq(true)
    BillDueInvoicesJob.perform_now
    expect(@invoice.reload.status).to eq('complete')
  end
  
end
