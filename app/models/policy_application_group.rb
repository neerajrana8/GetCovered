class PolicyApplicationGroup < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :agency, optional: true
  has_many :policy_applications
  has_many :model_errors, as: :model, dependent: :destroy

  enum status: %i[in_progress success error]

  def update_status
    if policy_applications.count == policy_applications_count && !all_errors_any?
      update(status: :success)
    elsif all_errors_any?
      update(status: :error)
    end
  end

  # Checks the errors existence without getting all of them from the database
  def all_errors_any?
    model_errors.any? || policy_applications_errors.any?
  end

  def all_errors
    model_errors | policy_applications_errors
  end

  private

  def policy_applications_errors
    join_query = <<-SQL
      LEFT JOIN policy_applications 
        ON model_errors.model_id = policy_applications.id AND model_errors.model_type = 'PolicyApplication' 
      LEFT JOIN policy_application_groups 
        ON policy_applications.policy_application_group_id = policy_application_groups.id
    SQL
    ModelError.joins(join_query).where(policy_application_groups: { id: id })
  end
end
