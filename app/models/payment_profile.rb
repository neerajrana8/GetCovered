class PaymentProfile < ApplicationRecord
  belongs_to :user

  serialize :source_id, StringEncrypterSerializer
  serialize :fingerprint, StringEncrypterSerializer

  enum source_type: { card: 0, bank_account: 1 }

  validates_presence_of :source_id, :source_type

  alias_attribute :default, :default_profile

  def set_default
    ActiveRecord::Base.transaction do
      user.payment_profiles.where.not(id: id).update_all(default_profile: false)
      update(default_profile: true)
    end
  end
end
