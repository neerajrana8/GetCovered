class AddCancellationConfigurationColumns < ActiveRecord::Migration[5.2]
  def up
    add_column :line_items, :full_refund_before_date, :date, null: true # default is nil
    add_column :carrier_policy_types, :premium_refundable, :boolean, null: false, default: true
    add_column :carrier_policy_types, :max_days_for_full_refund, :integer, null: false, default: 31
    add_column :carrier_policy_types, :days_late_before_cancellation, :integer, null: false, default: 30
    
    # update residential line items
    
    # set up pensio's non-default settings and update line items accordingly
    ::CarrierPolicyType.where(carrier_id: 4).update_all(
      premium_refundable: false
      max_days_for_full_refund: 4,
      days_late_before_cancellation: 60
    )
    Invoice.where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).references(:policy_applications).includes(:policy_application).where(policy_applications: { carrier_id: 4 }))
           .each do |invoice|
      invoice.line_items.where(category: 'base_premium', 'special_premium', 'taxes').update_all(refundability: 'no_refund', full_refund_before_date: invoice.created_at.to_date + 4.days)
    end
    
    
    
    
    nonrefundables = [4] # pensio
    LineItem.where(
      invoice_id: Invoice.select(:id).where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).references(:policy_applications).includes(:policy_application).where(policy_applications: { carrier_id: nonrefundables }))
                  .or(
                    Invoice.select(:id).where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).references(:policy_application_groups).includes(:policy_application_group).where(policy_application_groups: { carrier_id: nonrefundables }))
                  ),
      category: ['base_premium', 'special_premium', 'taxes']
    ).update_all(refundability: 'no_refund')
  end
  
  def down
    remove_column :carrier_policy_types, :days_late_before_cancellation
    remove_column :carrier_policy_types, :max_days_for_full_refund
    remove_column :carrier_policy_types, :premium_refundable
    remove_column :line_items, :full_refund_before_date
  end
end
