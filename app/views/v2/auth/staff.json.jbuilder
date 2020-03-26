json.extract! @staff, :id, :email, :organizable_type, 
                      :role, :enabled, :organizable_id
                      
json.profile_attributes do
  json.extract! @staff.profile, :id, :first_name, :middle_name, :last_name,
    :birth_date, :contact_email, :contact_phone, :job_title,
    :profileable_type, :profileable_id, :suffix
  
  json.full_name @staff.profile.full_name
end