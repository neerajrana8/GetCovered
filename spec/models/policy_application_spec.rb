# frozen_string_literal: true

RSpec.describe PolicyApplication, elasticsearch: true, type: :model do
  it 'PolicyApplication with reference Test should be indexed' do
    FactoryBot.create(:policy_application, reference: 'Test')
    PolicyApplication.__elasticsearch__.refresh_index!
    expect(PolicyApplication.search('Test').records.length).to eq(1)
  end

  it 'PolicyApplication with reference Wrong should not be indexed' do
    FactoryBot.create(:policy_application, reference: 'Test')
    PolicyApplication.__elasticsearch__.refresh_index!
    expect(PolicyApplication.search('Wrong').records.length).to eq(0)
  end
end
