# frozen_string_literal: true

require 'rails_helper'

describe 'Lease jobs spec', type: :request do
  
  it 'should deactivate expired leases' do
    expired_lease = Lease.new do |l|
      l.end_date = Time.current.to_date - 1.day
      l.insurable = FactoryBot.create(:insurable)
      l.lease_type = FactoryBot.create(:lease_type)
      l.account = FactoryBot.create(:account)
      l.status = 'current'
      l.start_date = 3.days.ago
      l.reference = 'test123'
    end
    expired_lease.save!
    LeaseExpirationCheckJob.perform_now
    expect(expired_lease.reload.status).to eq('expired')
  end
  
  it 'should activate starting today leases' do
    expired_lease = Lease.new do |l|
      l.end_date = 1.day.from_now
      l.insurable = FactoryBot.create(:insurable)
      l.lease_type = FactoryBot.create(:lease_type)
      l.account = FactoryBot.create(:account)
      l.status = 'approved'
      l.start_date = Time.current.to_date
      l.reference = 'test123'
    end
    expired_lease.save
    LeaseStartCheckJob.perform_now
    expect(expired_lease.reload.status).to eq('current')
  end
  
  
end