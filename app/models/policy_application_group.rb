class PolicyApplicationGroup < ApplicationRecord
  has_many :policy_applications
  has_many :model_errors, as: :model, dependent: :destroy

  enum status: %i[in_progress success error]

  def update_status
    if policy_applications.count == policy_applications_count && model_errors.empty?
      update(status: :success)
    elsif model_errors.present?
      update(status: :error)
    end
  end
end
