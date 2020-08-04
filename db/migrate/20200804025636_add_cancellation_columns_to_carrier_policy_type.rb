class AddCancellationColumnsToCarrierPolicyType < ActiveRecord::Migration[5.2]
  def up
    add_column :carrier_policy_types, :premium_refundable, :boolean, null: false, default: true
    add_column :carrier_policy_types, :max_days_for_full_refund, :integer, null: true, default: 30
    
    # set pensio premium_refundable to false & update all pensio premium line items accordingly
    ::CarrierPolicyType.where(carrier_id: 4).update_all(premium_refundable: false)
    LineItem.where(
      invoice_id: Invoice.select(:id).where(invoiceable_type: 'PolicyQuote', invoiceable_id: PolicyQuote.select(:id).references(:policy_applications).includes(:policy_application).where(policy_applications: { carrier_id: 4 }))
                  .or(
                    Invoice.select(:id).where(invoiceable_type: 'PolicyGroupQuote', invoiceable_id: PolicyGroupQuote.select(:id).references(:policy_application_groups).includes(:policy_application_group).where(policy_application_groups: { carrier_id: 4 }))
                  ),
      category: ['base_premium', 'special_premium', 'taxes']
    ).update_all(refundability: 'no_refund')
  end
  
  def down
    remove_column :carrier_policy_types, :max_days_for_full_refund
    remove_column :carrier_policy_types, :premium_refundable
  end
end
