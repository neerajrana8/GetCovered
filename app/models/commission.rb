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
class Commission < ApplicationRecord
  # Associations
  belongs_to :recipient,
    polymorphic: true
  
  has_many :commission_items
  
  # Validations
  validates_presence_of :status
  validates :status, uniqueness: { scope: [:recipient_type, :recipient_id] },
    if: Proc.new{|c| c.status == 'collating' }
  validates :total, numericality: { greater_than_or_equal_to: 0 },
    unless: Proc.new{|c| c.status == 'collating' }

  # Enums
  enum status: {
    collating: 0,
    awaiting_approval: 1,
    approved: 2,
    payout_error: 3,
    complete: 4
  }
  enum payout_method: {
    stripe: 0,
    manual: 1
  }
  
  # Public Class Methods
  def self.collating_commission_for(recipient)
    (@collating_commissions ||= {})[recipient] ||= ::Commission.find_or_create_by(recipient: recipient, status: 'collating')
  end
  
  def self.collating_commissions_for(recipients, apply_lock: false)
    found = (@collating_commissions ||= {}).select{|r,c| recipients.include?(r) }
    unless recipients.length == found.length
      found = ::Commission.where(recipient: recipients, status: 'collating')
      unless recipients.length == found.length
        found = found.to_a
        (recipients - found.map{|f| f.recipient }).each do |rec|
          found.push(::Commission.find_or_create_by(recipient: rec, status: 'collating'))
        end
      end
      found = found.map{|c| [c.recipient, c] }.to_h
      @collating_commissions.merge!(found)
    end
    if apply_lock
      ::Commission.where(id: found.values.map{|v| v.id }).order(id: :asc).lock.to_a
    end
    return found
  end
  
  # Public Instance Methods
  def separate_for_approval(which_items = self.commission_items, negative_payout: false)
    return { success: false, error: "Cannot separate an empty list of commission items" } if which_items.blank?
    return { success: false, error: "This commission has status '#{self.status}'; only 'collating' commissions can be separated!" } unless self.status == 'collating'
    created_commission = nil
    error_message = nil
    ActiveRecord::Base.transaction do
      self.lock!
      return { success: false, error: "This commission has status '#{self.status}'; only 'collating' commissions can be separated!" } unless self.status == 'collating'
      item_total = which_items.inject(0){|sum,item| sum + item.amount }
      created_commission = ::Commission.create(total: item_total, recipient: self.recipient, status: 'awaiting_approval', true_negative_payout: item_total < 0 && negative_payout, payout_method: self.payout_method)
      if created_commission.id.nil?
        error_message = "Failed to create separated commission, errors: #{created_commission.errors.to_h}"
        raise ActiveRecord::Rollback
      end
      unless self.update(total: self.total - item_total)
        error_message = "Failed to update total when separating commission, errors: #{self.errors.to_h}"
        raise ActiveRecord::Rollback
      end
      which_items.each do |item|
        unless item.update(commission: created_commission)
          error_message = "Failed to transfer CommissionItem ##{item.id} to separated commission, errors: #{item.errors.to_h}"
          raise ActiveRecord::Rollback
        end
      end
      if item_total < 0 && !negative_payout
        # if we "paid out" a negative commission without an override, it's really just a bookkeeping device; the debt rolls over, so we re-add that debt to ourselves immediately here
        debt_item = self.commission_items.create(
          amount: item_total,
          commissionable: created
        ) # this will update self.total to add the debt back in a callback, no need to do it manually
        if debt_item.id.nil?
          error_message = "Failed to create CommissionItem to log debt rollover for separate commission with negative balance, errors: #{debt_item.errors.to_h}"
          raise ActiveRecord::Rollback
        end
      end
    end
    return { success: false, error: error_message } unless error_message.nil?
    return { success: true, commission: created_commission }
  end
  
  def approve(approving_superadmin, with_payout_method: nil)
    return { success: false, error: "This commission has status '#{self.status}'; only 'awaiting_approval' commissions can be approved!" } unless self.status == 'awaiting_approval'
    error_message = nil
    ActiveRecord::Base.transaction do
      self.lock!
      return { success: false, error: "This commission has status '#{self.status}'; only 'awaiting_approval' commissions can be approved!" } unless self.status == 'awaiting_approval'
      unless self.update(status: "approved", approved_by: approving_superadmin, approved_at: Time.current, payout_method: with_payout_method || self.payout_method)
        return { success: false, error: "Approval of commission failed; errors: #{self.errors.to_h}" }
      end
    end
    ::StripeCommissionPayoutJob.perform_later([self]) if self.payout_method == 'stripe'
    return { success: true } # MOOSE WARNING: a job should pick up 'approved' commissions and pay them out
  end
  
  def mark_paid(marking_superadmin, with_payout_data: nil, with_payout_notes: nil)
    return { success: false, error: "This commission has status '#{self.status}' and payout_method '#{self.payout_method}'; only 'approved' and 'manual' commissions can be manually marked paid!" } unless self.status == 'approved' && self.payout_method == 'manual'
    ActiveRecord::Base.transaction do
      self.lock!
      return { success: false, error: "This commission has status '#{self.status}' and payout_method '#{self.payout_method}'; only 'approved' and 'manual' commissions can be manually marked paid!" } unless self.status == 'approved' && self.payout_method == 'manual'
      unless self.update(status: "complete", marked_paid_by: marking_superadmin, marked_paid_at: Time.current, payout_data: with_payout_data, payout_notes: with_payout_notes)
        return { success: false, error: "Failed to mark commission as paid; errors: #{self.errors.to_h}" }
      end
    end
    return { success: true }
  end
  
  def pay_with_stripe(marking_superadmin, with_payout_data: nil, with_payout_notes: nil)
    return { success: false, error: "This commission has status '#{self.status}' and payout_method '#{self.payout_method}'; only 'approved' and 'stripe' commissions can be paid with stripe!" } unless self.status == 'approved' && self.payout_method == 'stripe'
    ActiveRecord::Base.transaction do
      self.lock!
      return { success: false, error: "This commission has status '#{self.status}' and payout_method '#{self.payout_method}'; only 'approved' and 'stripe' commissions can be paid with stripe!" } unless self.status == 'approved' && self.payout_method == 'stripe'
      if self.total > 0
        transfer = nil
        begin
          transfer = Stripe::Transfer.create({
            amount: self.total,
            currency: 'usd',
            destination: self.recipient&.stripe_id
          })
        rescue Stripe::InvalidRequestError => e
          self.update(status: 'payout_error', error_info: e.message)
          return { success: false, error: e.message }
        rescue Stripe::StripeError => e
          self.update(status: 'payout_error', error_info: e.message)
          return { success: false, error: e.message }
        end
        unless self.update(status: 'complete', marked_paid_by: marking_superadmin, marked_paid_at: Time.current, stripe_transfer_id: transfer.id)
          self.update(status: 'payout_error', error_info: "Transfer succeeded, but failed to update the commission to reflect this; the transfer id was #{transfer.respond_to?(:id) ? transfer.id : 'N/A'}")
          return { success: false, error: "Transfer succeeded, but failed to update the commission to reflect this; the transfer id was #{transfer.respond_to?(:id) ? transfer.id : 'N/A'}" }
        end
      end
    end
    return { success: true }
  end



end
