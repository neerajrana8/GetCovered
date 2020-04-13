class PolicyApplicationGroup < ApplicationRecord
  has_many :policy_applications

  enum status: %i[in_progress success error]

  def update_status
    if policy_applications.count == policy_applications_count
      update(status: :success)
    end
  end
end
