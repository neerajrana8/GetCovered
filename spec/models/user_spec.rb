# frozen_string_literal: true

RSpec.describe User, elasticsearch: true, type: :model do
  it 'User with email test@test.com should be indexed' do
    FactoryBot.create(:user, email: email)
    User.__elasticsearch__.refresh_index!
    expect(User.search(email).records.length >= 1).to eq(true)
  end

  it 'User with email wrong@test.com should not be indexed' do
    FactoryBot.create(:user, email: 'test@test.com')
    User.__elasticsearch__.refresh_index!
    expect(User.search('wrong@example.com').records.length).to eq(0)
  end
end
