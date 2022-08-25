json.extract! contact_record, :id, :direction,:status, :contactable_type, :contactable_id, :body, :source, :subject, :created_at
json.extract! contact_record.contactable, :email
json.extract! contact_record.contactable.profile, :full_name
