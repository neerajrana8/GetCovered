# frozen_string_literal: true

RSpec.describe Lease, elasticsearch: true, type: :model do
  it 'Lease with reference test should be indexed' do
    FactoryBot.create(:lease, reference: 'test')
    Lease.__elasticsearch__.refresh_index!
    expect(Lease.search('test').records.length).to eq(1)
  end

  it 'Lease with reference wrong should not be indexed' do
    FactoryBot.create(:lease)
    Lease.__elasticsearch__.refresh_index!
    expect(Lease.search('wrong').records.length).to eq(0)
  end
end
