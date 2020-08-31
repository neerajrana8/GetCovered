class AddCancellationColumnsToCarrierPolicyType < ActiveRecord::Migration[5.2]
  def up
    add_column :carrier_policy_types, :premium_refundable, :boolean, null: false, default: true
    add_column :carrier_policy_types, :max_days_for_full_refund, :integer, null: false, default: 30
    add_column :carrier_policy_types, :days_late_before_cancellation, :integer, null: false, default: 30
    
    # set pensio days_late_before_cancellation
    ::CarrierPolicyType.where(carrier_id: 4).update_all(days_late_before_cancellation: 60)
    # set pensio premium_refundable to false & update all pensio premium line items accordingly
    nonrefundables = [4] # pensio
    ::CarrierPolicyType.where(carrier_id: nonrefundables).update_all(premium_refundable: false)
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
  end
end
