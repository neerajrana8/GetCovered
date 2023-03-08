class UserMergeJob < ApplicationJob
  queue_as :default # call it gordo

  def perform(days_to_check = 2)
    ActiveRecord::Base.logger.level = 1
    # generic systemwide user merges
    user_ids = User.where("created_at >= ?", (Time.current - days_to_check.days).beginning_of_day).order(id: :asc).pluck(:id)
    user_ids += PolicyUser.where("created_at >= ?", (Time.current - days_to_check.days).beginning_of_day).where.not(user_id: user_ids).pluck(:user_id)
    user_ids.each do |user_id|
      user = User.where(id: user_id).take
      next if user.nil?
      email = (user.email || user.profile.contact_email)
      next if email.blank?
      # grab generic systemwide matches
      matchez = Profile.where(profileable_type: "User", contact_email: email, first_name: user.profile.first_name, last_name: user.profile.last_name).where.not(profileable_id: user.id).pluck(:profileable_id)
      found = User.where(email: email).where.not(id: user.id).take
      matchez.push(found.id) if !found.nil? && found.profile.first_name == user.profile.first_name && found.profile.last_name == user.profile.last_name
      # grab first/last name matches from among residents on the appropriate policies
      LeaseUser.references(:leases).includes(:lease).where(
        leases: { insurable_id: PolicyInsurable.where(policy: user.policies.where(policy_type_id: 1), primary: true).select(:insurable_id) }
      ).select{|lu| lu.user&.profile&.first_name&.downcase&.strip == user.profile.first_name.downcase.strip && lu.user&.profile&.last_name&.downcase&.strip == user.profile.last_name.downcase.strip }
       .each{|lu| matchez.push(lu.user_id) }
      # consolidate matches
      next if matchez.blank?
      # merge matching users
      matchez.uniq!
      ActiveRecord::Base.transaction do
        users = ([user] + User.where(id: matchez).where.not(id: user.id).to_a).uniq
        us = users.sort_by{|x| [-x.sign_in_count, x.email.nil? ? 1 : 0, x.created_at] }
        while us.count > 1
          us[-2].absorb!(us[-1])
          us[-2].reload
          us.pop
        end
      end
    end
    
  end
  
end
