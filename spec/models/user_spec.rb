# frozen_string_literal: true

RSpec.describe User, elasticsearch: true, type: :model do
  it 'User with email test@test.com should be indexed' do
    FactoryBot.create(:user, email: 'test@test.com')
    User.__elasticsearch__.refresh_index!
    expect(User.search('test@test.com').records.length).to eq(1)
  end

  it 'User with email wrong@test.com should not be indexed' do
    FactoryBot.create(:user, email: 'test@test.com')
    User.__elasticsearch__.refresh_index!
    expect(User.search('wrong@example.com').records.length).to eq(0)
  end
end
