# Lease User model
# file: app/models/lease_user.rb

class LeaseUser < ApplicationRecord
  # Concerns
  
  # Callbacks
#   after_create :record_master_policy_coverage_user, :record_user_on_lease_history, :set_account_user
#   before_destroy :record_user_removed_on_lease_history
  
  # Relationships
  belongs_to :lease
  belongs_to :user
    
  def related_records_list
    return ['lease', 'user']  
  end
  
  private
# 
#     def record_master_policy_coverage_user
#       
#       # TODO need to refactor, because the lease has no unit in new schema
# 
#       #if lease.status == "current" && lease.unit.covered_by_master_policy
#       #  lease.unit.master_policy_coverage.master_policy_coverage_users.create({
#       #   user_id: self.user_id
#       # })
#       #end
#     end
#   
#     def record_user_on_lease_history
#       
#       related_history = {
#         data: { 
#           users: { 
#             model: 'User', 
#             id: user.id, 
#             message: "#{ user.profile.full_name } added to lease"
#           }
#         }, 
#         action: 'create_related'
#       }
#                 
#       self.related_records_list.each do |related|
#         self.send(related).histories.create(related_history) unless self.send(related).nil?  
#       end  
#       
#     end
#     
#     def record_user_removed_on_lease_history
#       
#       related_history = {
#         data: { 
#           users: { 
#             model: 'User', 
#             id: user.id, 
#             message: "#{ user.profile.full_name } removed from lease"
#           }
#         }, 
#         action: 'remove_related'
#       }
#                 
#       self.related_records_list.each do |related|
#         self.send(related).histories.create(related_history) unless self.send(related).nil?  
#       end  
#       
#     end
# 
#     def set_account_user
#       acct = AccountUser.where(user_id: user.id, account_id: lease.account_id).take
#       if acct.nil?
#         AccountUser.create!(user: user, account: lease.unit.parent_account)
#       elsif acct.status != 'enabled'
#         acct.update(status: 'enabled')
#       else
#         # do nothing
#       end
#     end
end
