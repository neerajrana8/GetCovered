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
    policy = FactoryBot.build(:policy)
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
    @invoices = Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).where(status: 'accepted', policy_id: policy_ids)).or(
                          Invoice.where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).where(status: 'accepted', policy_group_id: PolicyGroup.select(:id).policy_in_system(true).current.where(auto_pay: true)))
                       ).or(
                          Invoice.where(invoiceable_type: 'Policy', invoiceable_id: policy_ids)
                       ).where("due_date <= '#{Time.current.to_date.to_s(:db)}'").where(status: ['available', 'missed'], external: false).order(invoiceable_type: :asc, invoiceable_id: :asc, due_date: :asc)

    BillDueInvoicesJob.perform_now
    expect(@invoice.reload.status).to eq('complete')
  end
  
end
