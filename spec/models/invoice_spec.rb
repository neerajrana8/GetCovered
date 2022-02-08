# frozen_string_literal: true

RSpec.describe Invoice, elasticsearch: false, type: :model do

  before :each do
    invoice = FactoryBot.create(:invoice)
    invoice.payer.attach_payment_source("tok_visa", true)
    
    @invoice = invoice
  end
  
  

  it 'should be chargeable' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    @invoice.reload
    expect(result[:success]).to eq(true), "payment attempt failed with output: #{result}"
    expect(@invoice.total_received).to eq(@invoice.total_due)
    expect(@invoice.line_items.first.total_received).to eq(@invoice.line_items.first.total_due)
    expect(@invoice.status).to eq("complete")
  end
  
  it 'should be partially chargeable' do
    # charge our invoice
    to_charge = @invoice.total_payable / 2
    result = @invoice.pay(amount: to_charge, stripe_source: :default)
    @invoice.reload
    expect(result[:success]).to eq(true), "payment attempt failed with output: #{result}"
    expect(@invoice.total_received).to eq(to_charge)
    expect(@invoice.line_items.first.total_received).to eq(to_charge)
    expect(@invoice.status).to eq("available")
  end
  
  it 'should handle pre-payment cancellations correctly' do
    # reduce
    created = ::LineItemReduction.create!(
      reason: "Testing reductions",
      refundability: "cancel_only",
      amount: 1000,
      line_item: @invoice.line_items.first
    )
    HandleLineItemReductionsJob.perform_now
    @invoice.reload
    created.reload
    expect(@invoice.total_due).to eq(@invoice.original_total_due - 1000)
    expect(@invoice.total_payable).to eq(@invoice.original_total_due - 1000)
    expect(created.amount_successful).to eq(1000)
    expect(created.amount_refunded).to eq(0)
  end
  
  it 'should handle pre-payment cancellations correctly when refunds are allowed' do
    # reduce
    created = ::LineItemReduction.create!(
      reason: "Testing reductions",
      refundability: "cancel_or_refund",
      amount: 1000,
      line_item: @invoice.line_items.first
    )
    HandleLineItemReductionsJob.perform_now
    @invoice.reload
    created.reload
    expect(@invoice.total_due).to eq(@invoice.original_total_due - 1000)
    expect(@invoice.total_payable).to eq(@invoice.original_total_due - 1000)
    expect(created.amount_successful).to eq(1000)
    expect(created.amount_refunded).to eq(0)
  end
  

  
  it 'should handle post-payment cancellations correctly' do
    # charge it
    result = @invoice.pay(amount: @invoice.total_payable - 1000, stripe_source: :default)
    @invoice.reload
    expect(result[:success]).to eq(true), "payment attempt failed with output: #{result}"
    expect(@invoice.total_payable).to eq(1000)

    # reduce it
    created = ::LineItemReduction.create!(
      reason: "Testing reductions",
      refundability: "cancel_only",
      amount: 2000,
      line_item: @invoice.line_items.first
    )
    HandleLineItemReductionsJob.perform_now
    @invoice.reload
    created.reload
    
    # check it
    expect(@invoice.total_due).to eq(@invoice.original_total_due - 1000)
    expect(@invoice.total_payable).to eq(0)
    expect(created.amount_successful).to eq(1000)
    expect(created.amount_refunded).to eq(0)
  end
  

=begin
  before :all do
    invoice = FactoryBot.create(:invoice)
    invoice.payer.attach_payment_source("tok_visa", true)
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
          category: 'amortized_fees'
        }
      ]
    )
    invoice.save
    invoice.refresh
    invoice.save
    @invoice = invoice
  end

  
  it 'should be chargeable' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    @invoice.reload
    expect(result[:success]).to eq(true)
    expect(@invoice.status).to eq("complete")
  end
  
  it 'should refund correct amount' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    expect(result[:success]).to eq(true)
    # perform prorated refund
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    # check that the refunded numbers are correct
    @invoice.reload
    expect(@invoice.amount_refunded).to eq(6000)
    expect(@invoice.status).to eq('complete')
  end
  
  it 'should not refund extra when proration is applied twice' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    expect(result[:success]).to eq(true)
    # perform prorated refund
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    # check that the refunded numbers are correct
    @invoice.reload
    expect(@invoice.amount_refunded).to eq(6000)
    expect(@invoice.status).to eq('complete')
  end
  
  it 'should refund nothing when overridden appropriately' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    expect(result[:success]).to eq(true)
    # perform prorated refund
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_refund_override: {})
    expect(result).to eq(true)
    # check that the refunded numbers are correct
    @invoice.reload
    expect(@invoice.amount_refunded).to eq(0)
    expect(@invoice.status).to eq('complete')
  end
  
  it 'should handle refunds correctly when processing' do
    # charge our invoice
    result = @invoice.pay(stripe_source: :default)
    expect(result[:success]).to eq(true)
    # set invoice status to processing and pretend line items haven't been paid for yet
    @invoice.update(status: 'processing')
    @invoice.line_items.update_all(collected: 0)
    # perform prorated refund
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    # check that the refunded is pending
    @invoice.reload
    expect(@invoice.amount_refunded).to eq(0)
    expect(@invoice.has_pending_refund).to eq(true)
    # inform the invoice that the charge has succeeded and check the refunded amount
    @invoice.payment_succeeded(@invoice.charges.first)
    @invoice.reload
    expect(@invoice.status).to eq('complete')
    expect(@invoice.amount_refunded).to eq(6000)
    # repeat the proration and ensure nothing else is refunded
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    @invoice.reload
    expect(@invoice.status).to eq('complete')
    expect(@invoice.amount_refunded).to eq(6000)
  end
  
  it 'with available status should perform proration adjustment correctly' do
    # perform proration
    cancel_date = @invoice.term_first_date + 1.day # proration should refund half of the refundable premium by default
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    # check that the proration adjustment was applied
    @invoice.reload
    expect(@invoice.status).to eq('available')
    expect(@invoice.amount_refunded).to eq(0)
    expect(@invoice.proration_reduction).to eq(6000)
    expect(@invoice.total).to eq(@invoice.subtotal - 6000)
    expect(@invoice.has_pending_refund).to eq(false)
    @invoice.line_items.each do |li|
      if li.title == "Test Premium Refundable"
        expect(li.proration_reduction).to eq(li.price / 2)
      elsif li.title == "Test Premium Non-Refundable"
        expect(li.proration_reduction).to eq(1000)
      else
        expect(li.proration_reduction).to eq(0)
      end
    end
    # do it again to make sure it doesn't double-prorate
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    @invoice.reload
    expect(@invoice.status).to eq('available')
    expect(@invoice.amount_refunded).to eq(0)
    expect(@invoice.proration_reduction).to eq(6000)
    expect(@invoice.total).to eq(@invoice.subtotal - 6000)
    expect(@invoice.has_pending_refund).to eq(false)
    @invoice.line_items.each do |li|
      if li.title == "Test Premium Refundable"
        expect(li.proration_reduction).to eq(li.price / 2)
      elsif li.title == "Test Premium Non-Refundable"
        expect(li.proration_reduction).to eq(1000)
      else
        expect(li.proration_reduction).to eq(0)
      end
    end
    # pay the invoice to make sure it charges the correct amount
    result = @invoice.pay(stripe_source: :default)
    @invoice.reload
    expect(result[:success]).to eq(true)
    expect(@invoice.status).to eq("complete")
    expect(@invoice.total).to eq(@invoice.subtotal - 6000)
    expect(@invoice.charges.first.amount).to eq(@invoice.total)
    # prorate again to make sure nothing changes
    result = @invoice.apply_proration(cancel_date, refund_date: cancel_date, to_ensure_refunded: Proc.new{|li| li.title == 'Test Premium Non-Refundable' ? 1000 : 0 })
    expect(result).to eq(true)
    @invoice.reload
    expect(@invoice.status).to eq('complete')
    expect(@invoice.amount_refunded).to eq(0)
    expect(@invoice.has_pending_refund).to eq(false)
  end
  
=end
  
end





