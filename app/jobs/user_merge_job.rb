class UserMergeJob < ApplicationJob
  queue_as :default # call it gordo

  def perform(days_to_check = 2)
    ActiveRecord::Base.logger.level = 1
    # generic systemwide user merges
    user_ids = User.where("created_at >= ?", (Time.current - days_to_check.days).beginning_of_day)
           .or(User.where("updated_at >= ?", (Time.current - days_to_check.days).beginning_of_day))
           .order(id: :asc).pluck(:id)
    user_ids = Profile.where(profileable_type: "User").where("created_at >= ?", (Time.current - days_to_check.days).beginning_of_day)
           .or(Profile.where(profileable_type: "User").where("updated_at >= ?", (Time.current - days_to_check.days).beginning_of_day))
           .where.not(profileable_id: user_ids)
           .pluck(:profileable_id)
    user_ids += PolicyUser.where("created_at >= ?", (Time.current - days_to_check.days).beginning_of_day)
            .or(PolicyUser.where("updated_at >= ?", (Time.current - days_to_check.days).beginning_of_day))
            .where.not(user_id: user_ids).pluck(:user_id)
    user_ids += LeaseUser.where("created_at >= ?", (Time.current - days_to_check.days).beginning_of_day)
            .or(LeaseUser.where("updated_at >= ?", (Time.current - days_to_check.days).beginning_of_day))
            .where.not(user_id: user_ids).pluck(:user_id)
    user_ids.each do |user_id|
      user = User.where(id: user_id).take
      next if user.nil?
      matchez = []
      email = (user.email || user.profile.contact_email)
      # grab generic systemwide matches
      unless email.blank?
        matchez = Profile.where(profileable_type: "User", contact_email: email, first_name: user.profile.first_name, last_name: user.profile.last_name).where.not(profileable_id: user.id).pluck(:profileable_id)
        found = User.where(email: email).where.not(id: user.id).take
        matchez.push(found.id) if !found.nil? && found.profile.first_name == user.profile.first_name && found.profile.last_name == user.profile.last_name
      end
      # grab first/last name matches from among residents on the appropriate policies
      LeaseUser.references(:leases).includes(:lease).where(
        leases: { insurable_id: PolicyInsurable.where(policy: user.policies.where(policy_type_id: 1), primary: true).select(:insurable_id) }
      ).select{|lu| lu.user&.profile&.first_name&.downcase&.strip == user.profile.first_name.downcase.strip && lu.user&.profile&.last_name&.downcase&.strip == user.profile.last_name.downcase.strip }
       .each{|lu| matchez.push(lu.user_id) unless lu.user_id == user.id }
      # consolidate matchez and pull up the appropriate users
      next if matchez.blank?
      users = ([user] + User.where(id: matchez).to_a).uniq
      # merge matching users
      ActiveRecord::Base.transaction do
        users = users.sort_by{|x| [-x.sign_in_count, x.email.nil? ? 1 : 0, x.created_at] }
        while users.count > 1 && users[1].sign_in_count > 0
          users = users.drop(1) # disallow merges of multiple signed-in user accounts (for security)
        end
        while users.count > 1
          users[-2].absorb!(users[-1])
          users[-2].reload
          users.pop
        end
      end
    end
    
  end
  
end
