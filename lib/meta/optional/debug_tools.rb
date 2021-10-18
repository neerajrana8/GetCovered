





class Buglord




  def self.toggle_db_output
    return (ActiveRecord::Base.logger.level = (ActiveRecord::Base.logger.level == 1 ? 0 : 1)) == 1 ? "OFF" : "ON"
  end

  def self.call_controller_action(controller, action, params = nil)
    cont = controller.new # add string interpretation at some point
    cont.params = ActionController::Parameters.new(params) unless params.nil? # add string interpretation at some point
    cont.send(action)
  end



  def self.slaughter_policy_without_pa(pol, be_merciful: false)
    unless pol.invoices.map{|i| i.line_items.to_a.map{|li| li.line_item_changes.to_a } }.flatten.select{|lic| lic.field_changed == 'total_received' }.blank?
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


end
