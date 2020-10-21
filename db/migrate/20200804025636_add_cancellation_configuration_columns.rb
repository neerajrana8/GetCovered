class AddCancellationConfigurationColumns < ActiveRecord::Migration[5.2]
  def up
    add_column :line_items, :full_refund_before_date, :date, null: true # default is nil                  # support line items having a cutoff date for full refunds
    add_column :carrier_policy_types, :premium_refundable, :boolean, null: false, default: true           # whether the premium is generally refunded according to proration rules
    add_column :carrier_policy_types, :max_days_for_full_refund, :integer, null: false, default: 31       # the # of days from Policy.created_at (including created_at.to_date itself) when a full refund will be offered (excluding fees)
    add_column :carrier_policy_types, :days_late_before_cancellation, :integer, null: false, default: 30  # the # of days an invoice can be unpaid past its due date before a policy is canceled for nonpay

    # Set up residential policy values
    ::CarrierPolicyType.where(policy_type_id: PolicyType::RESIDENTIAL_ID).update_all(
      premium_refundable: true,
      max_days_for_full_refund: 31,
      days_late_before_cancellation: 30
    )
    # Set up commercial policy values
    ::CarrierPolicyType.where(policy_type_id: PolicyType::COMMERCIAL_ID).update_all(
      premium_refundable: false,
      max_days_for_full_refund: 0,
      days_late_before_cancellation: 14
    )
    # Set up rent guarantee policy values
    ::CarrierPolicyType.where(policy_type_id: PolicyType::RENT_GUARANTEE_ID).update_all(
      premium_refundable: false,
      max_days_for_full_refund: 4,
      days_late_before_cancellation: 60
    )
  end
  
  def down
    remove_column :carrier_policy_types, :days_late_before_cancellation
    remove_column :carrier_policy_types, :max_days_for_full_refund
    remove_column :carrier_policy_types, :premium_refundable
    remove_column :line_items, :full_refund_before_date
  end
end
