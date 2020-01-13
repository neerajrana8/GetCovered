# Assignment model
# file: app/models/assignment.rb

class Assignment < ApplicationRecord

  # after_create :record_related_history_create
  # before_destroy :record_related_history_destory
  before_create :set_first_as_primary
  after_save :switch_others_primary

  # Relationship
  belongs_to :staff
  belongs_to :assignable, polymorphic: true

  # Potential place for the optimization. Can reduce amount of request to database twice.
  # I decided to keep information about what insurables is communities, in one place.
  scope :communities, lambda {
    joins("LEFT JOIN insurables
           ON assignments.assignable_id = insurables.id AND assignments.assignable_type = 'Insurable'
           LEFT JOIN insurable_types 
           ON insurables.insurable_type_id = insurable_types.id")
      .where(insurable_types: { id: InsurableType.communities.ids })
  }

  # TODO: need to refactor because stuff has no account_id
  # validate :staff_and_community_share_account,
  #  unless: Proc.new { |assignment| 
  #    assignment.staff.nil? || 
  #   assignment.assignable.nil? || 
  #    !assignment.assignable.respond_to?(:account_id) 
  #  }

  def related_records_list
    %w[staff assignable]
  end

  private

  def record_related_history_create
    related_history = {
      data: {
        users: {
          model: 'Staff',
          id: staff.id,
          message: "#{staff.profile.full_name} assigned to #{assignable.title}"
        }
      },
      action: 'create_related'
    }

    related_records_list.each do |related|
      send(related)&.histories&.create(related_history)
    end
  end

  def record_related_history_destroy
    related_history = {
      data: {
        users: {
          model: 'Staff',
          id: staff.id,
          message: "#{staff.profile.full_name} removed from #{assignable.title}"
        }
      },
      action: 'remove_related'
    }

    related_records_list.each do |related|
      send(related)&.histories&.create(related_history)
    end
  end

  def set_first_as_primary
    unless assignable.nil?
      self.primary = true if assignable.assignments.count == 0
    end
  end

  def switch_others_primary
    assignable.assignments.where.not(id: id).update_all(primary: false) if primary
  end

  def one_primary_per_assignable
    errors.add(:primary, 'one primary per assignable') if primary == true && staff.assignments.count >= 1
  end

  # TODO: need to refactor because stuff has no account_id
  # def staff_and_community_share_account
  #  if staff.account_id != assignable.account_id
  #    errors.add(:staff, "does not have access to this community")
  #   end
  # end
end
