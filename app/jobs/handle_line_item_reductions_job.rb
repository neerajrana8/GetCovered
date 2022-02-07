class HandleLineItemReductionsJob < ApplicationJob
  queue_as :default

  def perform(*args, invoice_id: nil, invoice_ids: nil)
    invoice_ids = if !invoice_id.nil?
      [invoice_id]
    else
      LineItemReduction.references(:line_items).includes(:line_item).pending.order("line_items.invoice_id ASC").group("line_items.invoice_id").pluck("line_items.invoice_id")
    end if invoice_ids.nil?
    
    invoice_ids.each do |invid|
      ::Invoice.where(id: invid).take&.process_reductions
    end
  end
  
end
