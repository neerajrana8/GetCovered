json.extract! @user, :id, :email, :marital_status

json.profile_attributes do
  json.extract! @user.profile, :id, :first_name, :middle_name, :last_name,
    :birth_date, :contact_email, :contact_phone, :job_title,
    :profileable_type, :profileable_id
  
  json.full_name @user.profile.full_name
end