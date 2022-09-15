json.extract! contact_record, :id, :direction,:status, :contactable_type, :contactable_id, :body, :source, :subject, :created_at
json.email contact_record.contactable.contact_email
json.extract! contact_record.contactable.profile, :full_name
