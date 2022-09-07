# == Schema Information
#
# Table name: model_errors
#
#  id          :bigint           not null, primary key
#  model_type  :string
#  model_id    :bigint
#  kind        :string
#  information :jsonb
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  backtrace   :jsonb
#  description :text
#
class ModelError < ApplicationRecord
  after_create :send_error_notification

  belongs_to :model, polymorphic: true, required: false

  def subject
    if self.persisted?
      string = "#{ self.model_type } #{self.kind.gsub("_", " ").titlecase }".strip
      return string.blank? ? "New Application Error #{ self.created_at.strftime('%B %d, %Y, %H:%I:%S') }" : string
    else
      return nil
    end
  end

  private
  def send_error_notification
    InternalMailer.with(organization: Agency.find(1))
                  .model_error(error: self)
                  .deliver_now()
  end
end
