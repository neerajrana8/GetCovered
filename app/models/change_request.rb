class ChangeRequest < ApplicationRecord
  belongs_to :changeable, polymorphic: true
  belongs_to :requestable, polymorphic: true # User, Staff or other object/person who requests changes

  validate :uniqueness_inside_changeable
  # belongs_to :staff

  # Enum Options
  enum customized_action: %i[decline approve pending cancel refund]
  enum status: %i[awaiting_confirmation in_progress approved failed declined]

  private

  def uniqueness_inside_changeable
    if ChangeRequest.
        where(changeable: changeable, customized_action: customized_action).
        where.not(id: id).any?
      errors.add(:changeable, 'should have only one change request with specific action.')
    end
  end
end
