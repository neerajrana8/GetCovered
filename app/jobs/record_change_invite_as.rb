class RecordChangeInviteAs < ApplicationJob
  # pass serialized string
  def perform(object, params)
    performing_object = object.class == String ? PassingObjectSerializer.deserialize(object) : object
    performing_object.invite_as!(params[:inviter], params[:invite_as_params], send_invite: params[:send_invite] || true)
  end
end
