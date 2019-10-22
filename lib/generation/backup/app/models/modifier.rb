# Modifier model
# file: app/models/modifier.rb

class Modifier < ApplicationRecord

  # ActiveRecord Callbacks

  after_initialize :initialize_modifier

  # ActiveRecord Associations

  belongs_to :invoice

  # Validations

  validates :strategy, presence: true

  validates :amount, presence: true

  validates :tier, presence: true

  validates :condition, presence: true

  validates :invoice, presence: true
  
  validate :one_service_fee_per_invoice

  # Enums

  enum strategy: ['flat', 'percentage']

  enum tier: ['apply_first', 'apply_second'] # MOOSE WARNING: if you modify this, also modify self.pretax_tiers_in_order

  enum condition: ['no_condition', 'card_payment', 'bank_account_payment']

  def self.pretax_tiers_in_order
    ['apply_first', 'apply_second']
  end

  # Methods

  def should_apply?(payment_method)
    case condition
      when 'no_condition'
        return true
      when 'card_payment'
        return payment_method == 'card'
      when 'bank_account_payment'
        return payment_method == 'bank_account'
      else
        return true
    end
  end

  private

    def initialize_modifier
      # Blank for now...
    end
    
    def one_service_fee_per_invoice
      if invoice.modifiers.where(condition: 'card_payment').count > 0
        errors.add(:invoice, "one service fee per invoice.")  
      end
    end
end
