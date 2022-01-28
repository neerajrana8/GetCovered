json.array! @account_communities do |account|
  json.extract! account, :id, :title, :slug, :enabled, :account_id, :insurable_type_id, :insurable_id, :category, :covered, :agency_id, :policy_type_ids, :preferred_ho4, :confirmed, :occupied, :expanded_covered, :created_at
  json.buildings_count account.insurables.buildings.count
end