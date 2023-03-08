json.extract! carrier, :bindable, :call_sign, :enabled, :id,
  :integration_designation, :quotable, :rateable, :settings, :slug,
  :syncable, :title, :verifiable, :is_system, :synonyms
json.title carrier.title&.upcase_first
