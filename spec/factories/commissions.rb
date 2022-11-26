# == Schema Information
#
# Table name: commissions
#
#  id                   :bigint           not null, primary key
#  status               :integer          not null
#  total                :integer          default(0), not null
#  true_negative_payout :boolean          default(FALSE), not null
#  payout_method        :integer          default("stripe"), not null
#  error_info           :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  recipient_type       :string
#  recipient_id         :bigint
#  stripe_transfer_id   :string
#  payout_data          :jsonb
#  payout_notes         :text
#  approved_at          :datetime
#  marked_paid_at       :datetime
#  approved_by_id       :bigint
#  marked_paid_by_id    :bigint
#
FactoryBot.define do
  factory :commission do
    amount { 1000 }
    approved { false }
    paid { false }
    distributes { nil }
    association :commissionable, factory: :agency
  end
end
