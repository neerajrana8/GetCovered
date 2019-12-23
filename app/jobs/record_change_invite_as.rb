class RecordChangeInviteAs < ApplicationJob
  def perform(object, inviter:, invite_as_params: nil, send_invite: true)
    object.invite_as!(inviter, invite_as_params, send_invite: send_invite)
  end
end
