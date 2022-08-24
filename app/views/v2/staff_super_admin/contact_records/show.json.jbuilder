json.extract! @contact_record, :id, :direction,:status, :contactable_type, :contactable_id, :body, :source, :subject
if @user.present?
  json.extract! @user, :email
end