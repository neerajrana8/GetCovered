# == Schema Information
#
# Table name: line_item_changes
#
#  id                 :bigint           not null, primary key
#  field_changed      :integer          not null
#  amount             :integer          not null
#  new_value          :integer          not null
#  handled            :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  line_item_id       :bigint
#  reason_type        :string
#  reason_id          :bigint
#  handler_type       :string
#  handler_id         :bigint
#  error_info         :string
#  analytics_category :integer          default("other"), not null
#
class LineItemChange < ApplicationRecord
  include FinanceAnalyticsCategory # provides analytics_category enum
  
  belongs_to :line_item
  belongs_to :reason,
    polymorphic: true
  belongs_to :handler,
    polymorphic: true,
    optional: true
  
  has_many :commission_items,
    as: :reason
    
  before_create :set_analytics_category
    
  enum field_changed: {
    total_received: 0,
    total_due: 1
  }

  validates_presence_of :field_changed
  validates_presence_of :amount
  validates_presence_of :new_value
  
  
  def handle
    error_message = nil
    case self.line_item.chargeable_type
      when 'PolicyPremiumItemPaymentTerm', 'PolicyPremiumItem'
        ActiveRecord::Base.transaction do
          ppipt = self.line_item.chargeable_type == 'PolicyPremiumItemPaymentTerm' ? self.line_item.chargeable : nil
          ppi = ppipt.nil? ? self.line_item.chargeable : ppipt.policy_premium_item
          self.lock! # NOTE: all these locks are in a specific order to avoid deadlocking if multiple of these run at once. Don't flip 'em around.
          ppipt.lock! unless ppipt.nil?
          ppi.lock!
          ppic_array = ppi.policy_premium_item_commissions.order(id: :asc).lock.to_a
          commission_hash = ::Commission.collating_commissions_for(ppic_array.map{|ppic| ppic.recipient }.uniq, apply_lock: true)
          case self.field_changed
            when 'total_due'
              # update the PPI
              unless ppi.update(total_due: ppi.total_due + self.amount)
                error_message = "Failed to update PolicyPremiumItem! Errors: #{ppi.errors.to_h}"
                raise ActiveRecord::Rollback
              end
              # update the PPICs
              result = ppi.attempt_commission_update(self, ppic_array, commission_hash)
              unless result[:success]
                error_message = "Failed to update commissions! Errors: #{result[:error]}. Record: #{result[:record]}"
                raise ActiveRecord::Rollback
              end
              # update ourselves
              unless self.update(handled: true, handler: ppi)
                error_message = "Failed to update LineItemChange to reflect handling! Errors: #{self.errors.to_h}"
                raise ActiveRecord::Rollback
              end
              # MOOSE WARNING: not updating the PolicyPremium itself...
            when 'total_received'
              # update the PPI
              unless ppi.update(total_received: ppi.total_received + self.amount)
                error_message = "Failed to update PolicyPremiumItem! Errors: #{ppi.errors.to_h}"
                raise ActiveRecord::Rollback
              end
              # update the PPICs
              result = ppi.attempt_commission_update(self, ppic_array, commission_hash)
              unless result[:success]
                error_message = "Failed to update commissions! Errors: #{result[:error]}. Record: #{result[:record]}"
                raise ActiveRecord::Rollback
              end
              # update ourselves
              unless self.update(handled: true, handler: ppi)
                error_message = "Failed to update LineItemChange to reflect handling! Errors: #{self.errors.to_h}"
                raise ActiveRecord::Rollback
              end
          end #end case field_changed
        end # transaction
      else
        # mark ourselves handled so we stop coming up in the list; but handler has been left blank, so we can still identify these easily enough if needed
        unless self.update(handled: true)
          error_message = "Failed to mark handled true! Errors: #{self.errors.to_h}"
          raise ActiveRecord::Rollback
        end
    end
    self.update(error_info: error_message)
    return error_message
  end
  
  private
  
    def set_analytics_category
      self.analytics_category = self.line_item&.analytics_category || 'other'
    end
end
