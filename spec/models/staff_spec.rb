# frozen_string_literal: true

RSpec.describe Staff, elasticsearch: true, type: :model do
  it 'Staff with email test@test.com should be indexed' do
    FactoryBot.create(:staff, email: 'test@test.com')
    Staff.__elasticsearch__.refresh_index!
    expect(Staff.search('Test').records.length).to eq(1)
  end

  it 'Staff with email wrong@test.com should not be indexed' do
    FactoryBot.create(:staff, email: 'test@test.com')
    Staff.__elasticsearch__.refresh_index!
    expect(Staff.search('Wrong').records.length).to eq(0)
  end
end
