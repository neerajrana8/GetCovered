require 'rails_helper'

RSpec.describe PolicyQuote, elasticsearch: true, type:  :model do
  it 'PolicyQuote with reference Test should be indexed' do
    FactoryBot.create(:policy_quote, reference: 'Test')
    PolicyQuote.__elasticsearch__.refresh_index!
    expect(PolicyQuote.search('Test').records.length).to eq(1)
  end

  it 'PolicyQuote with reference Wrong should not be indexed' do
    FactoryBot.create(:policy_quote, reference: 'Test')
    PolicyQuote.__elasticsearch__.refresh_index!
    expect(PolicyQuote.search('Wrong').records.length).to eq(0)
  end
end
