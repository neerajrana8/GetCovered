class PaymentProfile < ApplicationRecord
  belongs_to :payer, polymorphic: true

  serialize :source_id, StringEncrypterSerializer
  serialize :fingerprint, StringEncrypterSerializer

  enum source_type: { card: 0, bank_account: 1 }

  validates_presence_of :source_id, :source_type

  alias_attribute :default, :default_profile
  
  before_create :scream
  
  def scream
    raise "OMG OMG PAYMENT PROFILE CREATED!!!"
  end

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
