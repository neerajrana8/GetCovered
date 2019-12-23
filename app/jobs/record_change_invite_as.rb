class RecordChangeInviteAs < ApplicationJob
  # pass serialized string
  def perform(object, inviter:, invite_as_params: nil, send_invite: true)
    performing_object = object.class == String ? Marshal.load(object) : object
    performing_object.invite_as!(inviter, invite_as_params, send_invite: send_invite)
  end
end
