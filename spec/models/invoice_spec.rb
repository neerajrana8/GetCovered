# frozen_string_literal: true

RSpec.describe Invoice, elasticsearch: true, type: :model do
  it 'Invoice with number should be indexed' do
    invoice = FactoryBot.create(:invoice)
    Invoice.__elasticsearch__.refresh_index!
    expect(Invoice.search(invoice.number).records.length).to eq(1)
  end

  it 'Invoice with wrong number 100 should not be indexed' do
    FactoryBot.create(:invoice)
    Invoice.__elasticsearch__.refresh_index!
    expect(Invoice.search('100').records.length).to eq(0)
  end
end
