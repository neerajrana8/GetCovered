json.extract! carrier, :id, :title, :slug, :call_sign, :integration_designation, :settings, :commission_strategy_id, :created_at, :updated_at, :synonyms
json.title carrier.title&.upcase_first
