

class LineItemChange < ApplicationRecord
  belongs_to :line_item
  belongs_to :reason,
    polymorphic: true
  belongs_to :handler,
    polymorphic: true,
    optional: true
    
  enum field_changed: {
    total_received: 0,
    total_due: 1
  }
  enum proration_interaction: {
    shared: 0,        # If we reduce by $10, and later a proration removes $5, the total reduction will be $10 (i.e. the prorated 5 will be part of the already-cancelled/refunded 10)
    duplicated: 1,    # If we reduce by $10, and later a proration removes $5, the total reduction will be $15, unless the line item TOTAL is less than $15, in which case it will be completely reduced (i.e. the proration attempts to apply as a separate, non-overlapping reduction when possible)
    reduced: 2        # If the proratable total is $20 and we reduce by $10, then a 50% proration will reduce 50% of the remaining $10 instead of the original $20, i.e. will reduce by 5 dollars (i.e. we reduce this and modify the totals so that it is as if this had never been part of the total at all)
  }

  validates_presence_of :field_changed
  validates :amount, numericality: { :greater_than_or_equal_to => 0 }
  validates_presence_of :proration_interaction,
    if: Proc.new{|lic| lic.field_changed == 'total_due' }
  
  
  def handle
    error_message = nil
    case self.line_item.chargeable_type
      when 'PolicyPremiumItemPaymentTerm', 'PolicyPremiumItem'
        ActiveRecord::Base.transaction do
          ppipt = self.line_item.chargeable_type == 'PolicyPremiumItemPaymentTerm' ? self.line_item.chargeable : nil
          ppi = ppipt.nil? ? self.line_item.chargeable : ppipt.policy_premium_item
          self.lock!
          ppipt.lock! unless ppipt.nil?
          ppi.lock!
          case self.field_changed
            when 'total_due'
              # update the PPIPT if it exists & we involve proration total reduction or reduction duplication
              case self.proration_interaction
                when 'duplicated'
                  unless ppipt.nil? || ppipt.update(duplicatable_reduction_total: ppipt.duplicatable_reduction_total - self.amount)
                    error_message = "Failed to update PolicyPremiumItemPaymentTerm! Errors: #{ppipt.errors.to_h}"
                    raise ActiveRecord::Rollback
                  end
                when 'reduced'
                  unless ppipt.nil? || ppipt.update(preproration_total_due: ppipt.preproration_total_due + self.amount) # MOOSE WARNING sign
                    error_message = "Failed to update PolicyPremiumItemPaymentTerm! Errors: #{ppipt.errors.to_h}"
                    raise ActiveRecord::Rollback
                  end
                else
                  # do nothing
              end
              # update the PPI
              unless ppi.update(self.proration_interaction == 'reduced' ?
                { total_due: ppi.total_due + self.amount, preproration_total_due: ppi.preproration_total_due + self.amount, preproration_modifiers: ppi.preproration_modifiers - 1 }
                : { total_due: ppi.total_due + self.amount }
              )
                error_message = "Failed to update PolicyPremiumItem! Errors: #{ppipt.errors.to_h}"
                raise ActiveRecord::Rollback
              end
              # update ourselves
              unless self.update(handled: true, handler: ppi)
                error_message = "Failed to update LineItemChange to reflect handling! Errors: #{self.errors.to_h}"
                raise ActiveRecord::Rollback
              end
            when 'total_received'
              # update the PPI
              unless ppi.update(total_received: ppi.total_received + self.amount)
                error_message = "Failed to update PolicyPremiumItem! Errors: #{ppipt.errors.to_h}"
                raise ActiveRecord::Rollback
              end
              # create the commission item
              created = ::CommissionItem.create(
                amount: self.amount,
                commission: ::Commission.collating_commission_for(ppi.recipient), # MOOSE WARNING WHAT IS THIS
                commissionable: ppi,
                policy: ppi.policy_quote.policy
              )
              unless created.id
                error_message = "Failed to create CommissionItem! Errors: #{created.errors.to_h}"
                raise ActiveRecord::Rollback
              end
              # update ourselves
              unless self.update(handled: true, handler: created)
                error_message = "Failed to update LineItemChange to reflect handling! Errors: #{self.errors.to_h}"
                raise ActiveRecord::Rollback
              end
          end #end case field_changed
        end # transaction
      else
        # mark ourselves handled so we stop coming up in the list; but handler has been left blank, so we can still identify these easily enough if needed
        self.update(handled: true)
    end
    return error_message
  end
  
end
