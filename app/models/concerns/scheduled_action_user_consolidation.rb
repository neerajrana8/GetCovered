

module ScheduledActionUserConsolidation
  extend ActiveSupport::Concern
  
  included do
    

    def perform_user_consolidation
      # prepare to act
      predecessor = ScheduledAction.where(action: self.action, status: 'complete').order(started_at: :desc).limit(1).take
      last_perfected_id = predecessor&.output&.[]('last_perfected_id') || 0
      ids_to_perfect = User.where(id: ((last_perfected_id+1)..(last_perfected_id + 500))).order(id: :asc).pluck(:id) # never handle more than 500 users in a single run
      last_to_perfect = ids_to_perfect.last
      # merge duplicate users
      ids_to_perfect.each do |user_id|
        user = User.references(:profiles).includes(:profile).where(id: user_id).take
        next if user.nil?
        # find duplicate users that should be merged with this one
        emails = [user.email, user.profile.contact_email].select{|x| !x.blank? }.uniq
        duplicate_ids = Profile.where(profileable_type: "User", contact_email: emails, first_name: user.profile.first_name, last_name: user.profile.last_name)
                               .where.not(id: user.profile.id)
                               .pluck(:profileable_id)
        if user.provider != 'email'
          duplicate_ids += User.references(:profiles).includes(:profile).where(email: emails, profiles: { first_name: user.profile.first_name, last_name: user.profile.last_name)
                                                                        .where.not(id: user.id)
                                                                        .pluck(:id)
        end
        duplicate_ids.uniq!
        duplicate_ids.select!{|id| id != user_id } # already in the queries, but let's be doubly sure in case someone carelessly modifies things later
        # merge any discovered duplicates
        next if duplicate_ids.blank?
        users = User.where(id: [user_id] + duplicate_ids).to_a
        us = users.sort_by{|x| [x.provider == 'email' ? 0 : 1, -x.sign_in_count, x.created_at] }
        while us.count > 1
          us[-2].absorb!(us[-1])
          us[-2].reload
          us.pop
        end
      end
      # log things and prepare successors
      self.output ||= {}
      self.output['last_perfected_id'] = last_to_perfect || last_perfected_id
      ######### MOOSE WARNING FINISH MEEE
      
      
    end
    
    
    
  end
end
