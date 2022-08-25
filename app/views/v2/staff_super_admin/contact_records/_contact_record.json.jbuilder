json.extract! contact_record, :id, :direction,:status, :contactable_type, :contactable_id, :body, :source, :subject
json.extract! contact_record.contactable, :email
json.extract! contact_record.contactable.profile, :full_name
