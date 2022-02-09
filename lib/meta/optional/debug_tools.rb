





class Buglord




  def self.toggle_db_output
    return (ActiveRecord::Base.logger.level = (ActiveRecord::Base.logger.level == 1 ? 0 : 1)) == 1 ? "OFF" : "ON"
  end

  def self.call_controller_action(controller, action, params = nil)
    cont = controller.new # add string interpretation at some point
    cont.params = ActionController::Parameters.new(params) unless params.nil? # add string interpretation at some point
    cont.send(action)
  end



  def self.slaughter_policy_without_pa(pol, be_merciful: false, force_unsafe: false)
    unless pol.invoices.map{|i| i.line_items.to_a.map{|li| li.line_item_changes.to_a } }.flatten.select{|lic| lic.field_changed == 'total_received' }.blank?
      return slaughter_policy_unsafely(pol) if be_merciful == false && force_unsafe == "I am emperor over all meese; no moose shall usurp me!"
      return "You cannot slaughter this policy because it has associated line items with total_recieved LineItemChanges... we can't just erase the financial data, and automatically correcting commissions here would be dangerous; therefore I merely scream instead. YOU CAN'T DO IT, SLIMEFACE!!!"
    end
    condemned = [
      pol,
      pol.policy_quotes.first,
      pol.policy_premiums.first,
      pol.policy_premiums.first&.policy_premium_items&.to_a,
      pol.policy_premiums.first&.policy_premium_item_commissions&.to_a,
      # shouldn't exist without payments: pol.policy_premiums.first.policy_premium_items.map{|ppi| ppi.policy_premium_item_transactions.to_a },                                                               # should only be around for master policies
      # shouldn't exist without payments: pol.policy_premiums.first.policy_premium_items.map{|ppi| ppi.policy_premium_item_transactions.map{|ppit| ppit.policy_premium_item_transaction_memberships.to_a } }, # should only be around for master policies
      pol.policy_premiums.first&.policy_premium_payment_terms&.to_a,
      pol.policy_premiums.first&.policy_premium_payment_terms&.map{|pppt| pppt.policy_premium_item_payment_terms.to_a },
      pol.invoices.to_a,
      pol.invoices.map{|i| i.line_items.to_a },
      pol.invoices.map{|i| i.line_items.map{|li| li.line_item_changes.to_a } }
    ].flatten.compact.uniq
    tr = condemned.group_by{|c| c.class.name }.transform_values{|cs| cs.map{|cs| cs.id } }
    unless be_merciful
      begin
        ActiveRecord::Base.transaction do
          condemned.each{|c| c.delete }
        end
      rescue
        return "Failed to delete! Error occurred! Oh no batman! Oh no!!!! Rolled back the tranny tho! Should be coo'! SHOULD BE OKAYYYYYYY"
      end
    end
    return tr
  end
  
  
  private
  
    def self.slaughter_policy_unsafely(pol, be_merciful: false)
      return "You cannot slaughter this policy; it has already received payments, and lib/meta/optional/debug_tools.rb's slaughter_policy_unsafely method does not yet have handling for refunding/deleting StripeCharges and ExternalCharges and refunds and their ilk"
      # get commission information
      number = pol.number
      cis = CommissionItem.where(policy_id: pol.id).or(CommissionItem.where(policy_id: nil, policy_quote_id: pol.policy_quotes.map{|pq| pq.id })).to_a
      if cis.select{|ci| ci.policy_id.nil? }
        # if more than one policy was made from the same policy quote somehow, and some payments only have the quote id, only take the ones made between our creation and the creation of our successor
        brethren = self.policy_quotes.map{|pq| pq.policy }.compact.uniq.sort_by{|b| b.created_at }
        if brethren.length > 1
          self_index = brethren.find_index{|b| b == pol }
          cis.select!{|ci| !ci.policy_id.nil? || (ci.policy_id.nil? && ci.created_at >= brethren[self_index].created_at && ci.created_at < (brethren[self_index + 1]&.created_at || Float::INFINITY)) }
        end
      end
      # MOOSE WARNING: THIS IS NOT DONE
      # kill stuff
      condemned = [
        pol,
        pol.policy_quotes.first,
        pol.policy_premiums.first,
        pol.policy_premiums.first&.policy_premium_items&.to_a,
        pol.policy_premiums.first&.policy_premium_item_commissions&.to_a,
        pol.policy_premiums.first&.policy_premium_items.map{|ppi| ppi.policy_premium_item_transactions.to_a },                                                               # should only be around for master policies
        pol.policy_premiums.first&.policy_premium_items.map{|ppi| ppi.policy_premium_item_transactions.map{|ppit| ppit.policy_premium_item_transaction_memberships.to_a } }, # should only be around for master policies
        pol.policy_premiums.first&.policy_premium_payment_terms&.to_a,
        pol.policy_premiums.first&.policy_premium_payment_terms&.map{|pppt| pppt.policy_premium_item_payment_terms.to_a },
        pol.invoices.to_a,
        pol.invoices.map{|i| i.line_items.to_a },
        pol.invoices.map{|i| i.line_items.map{|li| li.line_item_changes.to_a } }
      ].flatten.compact.uniq
      tr = condemned.group_by{|c| c.class.name }.transform_values{|cs| cs.map{|cs| cs.id } }
      unless be_merciful
        # delete CIs first because if we delete the policy first and fail to kill some cis, there will be dangling references to a destroyed policy (and we won't be able to get the number next time either)
        begin
          cis.each do |ci|
            if ci.commission.status == 'collating'
              ActiveRecord::Base.transaction do
                ci.commission.lock!
                ci.commission.update!(total: ci.commission.total - ci.amount)
                ci.delete
              end
            else
              ActiveRecord::Base.transaction do
                boyo = CommissionItem.create!(amount: -ci.total, commissionable: ci, reason: ci, analytics_category: ci.analytics_category,
                  notes: "To cancel out commission item ##{ci.id}; this commission item was paid out for Policy ##{number}, a policy erroneously entered into the system which has since been removed",
                  commission: Commission.collating_commision_for(ci.recipient)
                )
                ci.update!(commissionable: ci, reason: ci,
                  notes: "This commission item was for policy ##{number}, a policy erroneously entered into the system which has since been removed; it was cancelled out by commission item ##{boyo.id}"
                )
              end
            end
          end
          ActiveRecord::Base.transaction do
            condemned.each{|c| c.delete }
          end
        rescue
          return "Failed to delete! Error occurred! Oh no batman! Oh no!!!! Rolled back the tranny tho! Should be coo'! SHOULD BE OKAYYYYYYY"
        end
      end
      return tr
    end


end
