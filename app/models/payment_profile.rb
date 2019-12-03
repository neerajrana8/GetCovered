class PaymentProfile < ApplicationRecord
  belongs_to :user

  serialize :source_id, StringEncrypterSerializer
  serialize :fingerprint, StringEncrypterSerializer

  enum source_type: { card: 0, bank_account: 1 }

  validates_presence_of :source_id, :source_type
end
