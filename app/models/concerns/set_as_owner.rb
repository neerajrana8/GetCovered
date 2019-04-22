# SetAsOwner Concern
# file: app/models/concerns/set_as_owner.rb

module SetAsOwner
  extend ActiveSupport::Concern

  included do
    after_create :set_as_owner
  end

  def set_as_owner
    
    parent_class = self.class.name
    
    if parent_class === 'Agent'
      if agency.agents.count === 1
        
        agency.update(agent_id: id, enabled: true, owned: true)
      
      end  
    elsif parent_class === 'Staff'
      # if account.staffs.count === 1
        
      #   account.update(staff_id: id, enabled: true, owned: true)
      #   update_column(:permissions, "owner")
         
      # end      
    end
    
  end
  
end