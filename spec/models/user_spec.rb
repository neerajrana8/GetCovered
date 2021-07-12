# frozen_string_literal: true

RSpec.describe User, elasticsearch: true, type: :model do
  it 'User with email test@test.com should be indexed' do
    emaili = 0
    while User.where(email: "test#{emaili == 0 ? '' : emaili}@test.com").count > 0
      email += 1
    end
    email = "test#{emaili == 0 ? '' : emaili}@test.com"
    FactoryBot.create(:user, email: email)
    User.__elasticsearch__.refresh_index!
    expect(User.search(email).records.length).to eq(1)
  end

  it 'User with email wrong@test.com should not be indexed' do
    FactoryBot.create(:user, email: 'test@test.com')
    User.__elasticsearch__.refresh_index!
    expect(User.search('wrong@example.com').records.length).to eq(0)
  end
end
