# == Schema Information
#
# Table name: payment_profiles
#
#  id              :bigint           not null, primary key
#  source_id       :string
#  source_type     :integer
#  fingerprint     :string
#  default_profile :boolean          default(FALSE)
#  active          :boolean
#  verified        :boolean
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  payer_type      :string
#  payer_id        :bigint
#  card            :jsonb
#
class PaymentProfile < ApplicationRecord
  belongs_to :payer, polymorphic: true

  serialize :source_id, StringEncrypterSerializer
  serialize :fingerprint, StringEncrypterSerializer

  enum source_type: { card: 0, bank_account: 1 }

  validates_presence_of :source_id, :source_type

  alias_attribute :default, :default_profile

  def set_default
    succeeded = false
    ActiveRecord::Base.transaction do
      payer.payment_profiles.where.not(id: id).update_all(default_profile: false)
      raise ActiveRecord::Rollback unless update(default_profile: true)
      succeeded = true
    end
    return succeeded
  end
end
