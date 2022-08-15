# frozen_string_literal: true

# == Schema Information
#
# Table name: carrier_policy_types
#
#  id                                :bigint           not null, primary key
#  policy_defaults                   :jsonb
#  application_fields                :jsonb
#  application_questions             :jsonb
#  application_required              :boolean          default(FALSE), not null
#  carrier_id                        :bigint
#  policy_type_id                    :bigint
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  max_days_for_full_refund          :integer          default(31), not null
#  days_late_before_cancellation     :integer          default(30), not null
#  commission_strategy_id            :bigint           not null
#  premium_proration_calculation     :string           default("per_payment_term"), not null
#  premium_proration_refunds_allowed :boolean          default(TRUE), not null
#
RSpec.describe CarrierPolicyType, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
