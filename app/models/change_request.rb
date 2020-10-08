class ChangeRequest < ApplicationRecord
  belongs_to :changeable, polymorphic: true
  belongs_to :requestable, polymorphic: true

  validate :uniqueness_inside_requestable
  # belongs_to :staff

  # Enum Options
  enum customized_action: %i[decline approve pending cancel]
  enum status: %i[awaiting_confirmation in_progress approved failed declined]

  private

  def uniqueness_inside_requestable
    if ChangeRequest.
        where(requestable: changeable, customized_action: customized_action, status: status).
        where.not(id: id).any?
      errors.add(:requestable, 'should have only one change request with specific action and status.')
    end
  end
end
