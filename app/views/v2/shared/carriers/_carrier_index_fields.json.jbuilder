json.extract! carrier, :call_sign, :enabled, :id, :syncable, :title, :verifiable, :synonyms
json.title carrier.title&.upcase_first
