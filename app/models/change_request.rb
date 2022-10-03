# == Schema Information
#
# Table name: change_requests
#
#  id                :bigint           not null, primary key
#  reason            :text
#  customized_action :integer          default("decline")
#  method            :string
#  field             :string
#  current_value     :string
#  new_value         :string
#  status            :integer          default("awaiting_confirmation")
#  status_changed_on :datetime
#  staff_id          :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  changeable_type   :string
#  requestable_id    :integer
#  requestable_type  :string
#  changeable_id     :integer
#
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
