class Dispute < ApplicationRecord
    # ActiveRecord Callbacks

  after_initialize :initialize_dispute

  before_validation :set_active_flag

  after_create :handle_new_dispute,
    if: Proc.new { |dspt| dspt.active }

  after_save :handle_closed_dispute,
    if: Proc.new { |dspt| !dspt.active && dspt.saved_change_to_active? }

  # ActiveRecord Associations

  belongs_to :charge
  
  belongs_to :invoice, through: :charge

  # Validations

  validates :stripe_id, presence: true

  validates :amount, presence: true

  validates :reason, presence: true

  validates :status, presence: true

  validates_inclusion_of :active, in: [true, false],
    message: "can't be blank"

  # Enums

  enum status: ['warning_needs_response', 'warning_under_review', 'warning_closed', 'needs_response', 'under_review', 'charge_refunded', 'won', 'lost'] # these are in 1-to-1 correspondence with Stripe's Dispute::status values

  enum reason: ['duplicate', 'fraudulent', 'subscription_canceled', 'product_unacceptable', 'product_not_received', 'unrecognized', 'credit_not_processed', 'general', 'incorrect_account_details', 'insufficient_funds', 'bank_cannot_process', 'debit_not_authorized', 'customer_initiated'] # these are in 1-to-1 correspondence with Stripe's Dispute::reason values

  # Class Methods

  def self.closed_dispute_statuses
    ['charge_refunded', 'lost', 'warning_closed', 'won']
  end

  # Methods

  def update_from_stripe_hash(dispute_hash)
   invoice.with_lock do # we lock the invoice to ensure serial processing with other invoice events
      update(
        amount: dispute_hash['amount'],
        reason: dispute_hash['reason'],
        status: dispute_hash['status']
      ) # only status should change, but update the rest just in case
    end
  end

  private

    def set_active_flag
      self.active = !self.class.closed_dispute_statuses.include?(status)
    end

    def handle_new_dispute
      unless charge.react_to_new_dispute
        errors.add(:base, "charge new dispute handling error")
        raise ActiveRecord::Rollback
      end
    end

    def handle_closed_dispute
      if Dispute.closed_dispute_statuses.include?(status)
        raise ActiveRecord::Rollback unless charge.react_to_dispute_closure(id, status == 'lost' ? amount : 0)
      end
    end
end
