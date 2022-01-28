json.array! @account_communities do |community|
  json.extract! community, :id, :title, :slug, :enabled, :account_id, :insurable_type_id, :insurable_id, :category, :covered, :agency_id, :policy_type_ids, :preferred_ho4, :confirmed, :occupied, :expanded_covered, :created_at
  json.buildings_count community.buildings.count
end