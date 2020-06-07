# frozen_string_literal: true

require 'rails_helper'

describe 'Bill due invoice spec', type: :request do
  before(:each) do
    user = FactoryBot.create(:user)
    policy_type = PolicyType.find_by_title('Residential')
    policy = FactoryBot.build(:policy)
    policy.policy_in_system = true
    policy.policy_type = policy_type
    policy.billing_enabled = true
    policy.save!
    
    @invoice = Invoice.new do |i|
      i.user = user
      i.status = 'available'
      i.number = Time.now.to_i
      i.due_date = Time.current
      i.available_date = 1.day.ago
      i.policy = policy
    end
    @invoice.save!
  end
  
  it 'should pay invoices' do
    BillDueInvoicesJob.perform_now
  end
  
end
