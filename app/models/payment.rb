# Policy model
# file: app/models/payment.rb

class Payment < ApplicationRecord
=begin
  # Concerns
  include RecordChange

  # Refund Failure Exception
  class RefundFailureException < RuntimeError
    attr_accessor :amount_remaining
    attr_accessor :failed_payment
    def initialize(amount_remaining_, failed_payment_)
      @amount_remaining = amount_remaining_
      @failed_payment = failed_payment_
    end
  end
  
  # Active Record Callbacks
  after_initialize :initialize_payment

  after_update :record_status_changes
 
  # Relationships
  belongs_to :invoice

  belongs_to :charge
    
  has_one :agency,
    through: :policy
    
  has_one :user,
    through: :invoice

  has_many :histories,
    as: :recordable

  # Validations
  validates :status,
    presence: true

  validates :amount,
    presence: true,
    numericality: { greater_than: 0.01 }

  validates :stripe_id,
    presence: true

  # Enum Options
  enum status: ['incomplete', 'processing', 'complete', 'rejected', 'refunded', 'partially-refunded']
  # TODO fil reason 
  enum reason: []


  # Methods
  def related_records_list
    return ['policy', 'agency', 'user']  
  end


  # Applies as much of refund_amount as we can to this payment as a refund,
  # and returns the amount that remains to be refunded.
  # Throws a Payment::RefundFailureException on stripe errors.

  # TODO. Need to refactor this method. We have no amount_refunded!

  def apply_refund(refund_amount, extra_cents_to_refund_if_present = 0)
    refundable_amount = amount.to_f - amount_refunded.to_f
    if refundable_amount <= refund_amount || refundable_amount <= refund_amount + extra_cents_to_refund_if_present / 100.0
      begin
        stripe_refund = Stripe::Refund.create({
          charge: stripe_id
        })
      rescue
        raise RefundFailureException.new(refund_amount, self)
      end
      update_columns({
        status: 'refunded',
        amount_refunded: amount
      })
      return(refund_amount - refundable_amount)
    else
      begin
        refund = Stripe::Refund.create({
          charge: stripe_id,
          amount: (refund_amount * 100.0).floor.to_i
        })
      rescue
        raise RefundFailureException.new(refund_amount, self)
      end
      update_columns({
        status: 'partially-refunded',
        amount_refunded: refund_amount
      })
      return(0.0)
    end
  end

  private

    def initialize_payment
      # self.amount_refunded ||= '0.00' # Can we delete this? We have no amount_refunded!
      # self.user_in_system = true if self.user_in_system.nil?
    end

    def record_status_changes
      if self.will_save_changes_to_attribute?(:status)
        case status
          when 'complete'
            related_history = { 
              data: { 
                payments: { 
                  model: "Payment", 
                  id: id, 
                  message: "Payment ID:#{id} completed"
                } 
              }, 
              action: 'update_related' 
            }
            self.related_records_list.each do |related|
              self.send(related).histories.create(related_history) unless self.send(related).nil?  
            end
          when 'rejected'
            related_history = { 
              data: { 
                payments: { 
                  model: "Payment", 
                  id: id, 
                  message: "Payment ID:#{id} rejected"
                } 
              }, 
              action: 'update_related' 
            }
            self.related_records_list.each do |related|
              self.send(related).histories.create(related_history) unless self.send(related).nil?  
            end
        end
      end
    end

    # History methods

    def related_classes_through
      [ :agency, :policy, :user ]
    end

    def related_create_hash(relation, related_model)
      {
        self.class.name.to_s.downcase.pluralize => {
          "model" => self.class.name.to_s,
          "id" => self.id,
          "message" => "New payment#{ relation == :user ? "" : " from #{user.profile.full_name}" }#{ relation == :policy || policy.number.nil? ? "" : " for policy #{policy.number}" }"
        }
      }
    end
=end
end
