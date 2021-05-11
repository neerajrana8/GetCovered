FactoryBot.define do
  factory :invoice do
    association :invoiceable, factory: :policy
    association :payer, factory: :user
    collector { Agency.find(1) }
    
    #collector_type { "Agency" }
    #collector_id { 1 }
    
    available_date { 1.day.ago }
    due_date { 1.day.from_now }
    external { false }
    status { 'available' }
    
    original_total_due { 0 }
    total_due { 0 }
    total_payable { 0 }
    
    after(:create) do |invoice|
      result = create(:line_item, invoice: invoice, chargeable: invoice.invoiceable)
      invoice.reload
      invoice.send(:mark_line_items_priced_in)
      invoice.line_items.each{|li| li.save! }
      invoice.save!
    end
  end
end
