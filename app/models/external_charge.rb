class ExternalCharge < ApplicationRecord
  include DirtyTransactionTracker
  
  belongs_to :invoice
  
  before_save :handle_status_change,
    if: Proc.new{|ec| ec.will_save_change_to_attribute?('status') }
  after_commit :process,
    if: Proc.new{|ec| !ec.processed && ec.saved_change_to_attribute_within_transaction?('status') }
  
  validates_presence_of :status
  validates_presence_of :external_reference
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validate :invoice_is_external
  
  enum status: {
    pending: 1,
    succeeded: 2,
    failed: 3
  }
  
  def process
    self.with_lock do
      if !self.processed
        self.invoice.process_external_charge(self)
      end
    end
  end
  
  private
  
    def handle_status_change
      self.status_changed_at = Time.current
    end
  
    def invoice_is_external
      errors.add(:invoice, "must be external") if self.invoice.nil? || !self.invoice.external
    end
  
end
