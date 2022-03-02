json.array! @account_communities do |community|
  json.extract! community, :id, :title, :slug, :enabled, :account_id, :insurable_type_id, :insurable_id, :category, :covered, :agency_id, :policy_type_ids, :preferred_ho4, :confirmed, :occupied, :expanded_covered, :created_at
  json.buildings_count community.buildings.count
  json.addresses_attributes do
    unless community.addresses.nil?
      json.array! community.addresses do |insurable_addresses|
        json.partial! "v2/staff_super_admin/addresses/address_show_fields.json.jbuilder",
                      address: insurable_addresses
      end
    end
  end
end