# frozen_string_literal: true

RSpec.describe Invoice, elasticsearch: true, type: :model do

  before :all do
    invoice = FactoryBot.create(:invoice)
    invoice.user.attach_payment_source("tok_visa", true)
    invoice.update(
      status: 'available',
      number: 'test_invoice',
      due_date: Time.current.to_date,
      available_date: Time.current.to_date - 1.day,
      term_first_date: Time.current.to_date,
      term_last_date: Time.current.to_date + 3.days,
      line_items_attributes: [
        {
          title: "Test Premium Refundable",
          price: 10000,
          refundability: 'prorated_refund',
          category: 'base_premium'
        },
        {
          title: "Test Premium Non-Refundable",
          price: 10000,
          refundability: 'no_refund',
          category: 'base_premium'
        },
        {
          title: "Test Fee",
          price: 5000,
          refundability: 'no_refund',
          category: 'amorized_fees'
        }
      ]
    )
    invoice.refresh
    invoice.save
    @invoice = invoice
  end

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
  
  it 'Invoice should be chargeable' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    @invoice.reload
    expect(result[:success]).to eq(true)
    expect(@invoice.status).to eq("complete")
  end
  
  it 'Invoice should refund correct amount' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    expect(result[:success]).to eq(true)
    # perform prorated refund
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? li.price : 0 })
    expect(result).to eq(true)
    # check that the refunded numbers are correct
    @invoice.reload
    expect(@invoice.amount_refunded).to eq(15000)
  end
  
  it 'Invoice should handle refunds correctly when processing' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    expect(result[:success]).to eq(true)
    # set invoice status to processing and pretend line items haven't been paid for yet
    @invoice.update(status: 'processing')
    @invoice.line_items.update_all(collected: 0)
    # perform prorated refund
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? li.price : 0 })
    expect(result).to eq(true)
    # check that the refunded is pending
    @invoice.reload
    expect(@invoice.amount_refunded).to eq(0)
    expect(@invoice.has_pending_refund).to eq(true)
    # inform the invoice that the charge has succeeded and check the refunded amount
    @invoice.payment_succeeded(@invoice.charges.first)
    @invoice.reload
    expect(@invoice.status).to eq('complete')
    expect(@invoice.amount_refunded).to eq(15000)
  end
end





