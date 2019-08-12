# Assignment model
# file: app/models/assignment.rb

class Assignment < ApplicationRecord
  
  after_create :record_related_history_create
  before_destroy :record_related_history_destory
  
  # Relationship
  belongs_to :staff
  belongs_to :assignable, polymorphic: true 

  # TODO need to refactor because stuff has no account_id
  #validate :staff_and_community_share_account,
  #  unless: Proc.new { |assignment| 
  #    assignment.staff.nil? || 
  #   assignment.assignable.nil? || 
  #    !assignment.assignable.respond_to?(:account_id) 
  #  }
    
  def related_records_list
    return ['staff', 'assignable']  
  end 
    
  private
    
    def record_related_history_create
      
      related_history = {
        data: { 
          users: { 
            model: 'Staff', 
            id: staff.id, 
            message: "#{ staff.profile.full_name } assigned to #{ assignable.name }"
          }
        }, 
        action: 'create_related'
      }
                
      self.related_records_list.each do |related|
        self.send(related).histories.create(related_history) unless self.send(related).nil?  
      end 
    
    end
    
    def record_related_history_destory
      
      related_history = {
        data: { 
          users: { 
            model: 'Staff', 
            id: staff.id, 
            message: "#{ staff.profile.full_name } removed from #{ assignable.name }"
          }
        }, 
        action: 'remove_related'
      }
                
      self.related_records_list.each do |related|
        self.send(related).histories.create(related_history) unless self.send(related).nil?  
      end 
    
    end
    
    # TODO need to refactor because stuff has no account_id
    # def staff_and_community_share_account
    #  if staff.account_id != assignable.account_id
    #    errors.add(:staff, "does not have access to this community")
    #   end
    # end
    
end
