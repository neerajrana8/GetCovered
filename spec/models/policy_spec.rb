# frozen_string_literal: true

RSpec.describe Policy, elasticsearch: true, type: :model do
  it 'Policy with number 100 should be indexed' do
    FactoryBot.create(:policy, number: '100')
    Policy.__elasticsearch__.refresh_index!
    expect(Policy.search('100').records.length).to eq(1)
  end

  it 'Policy with wrong number 101 should not be indexed' do
    FactoryBot.create(:policy, number: '100')
    Policy.__elasticsearch__.refresh_index!
    expect(Policy.search('101').records.length).to eq(0)
  end
end
