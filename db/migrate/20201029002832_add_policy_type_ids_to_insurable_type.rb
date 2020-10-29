class AddPolicyTypeIdsToInsurableType < ActiveRecord::Migration[5.2]
  def up
    add_column :insurable_types, :policy_type_ids, :bigint, array: true, null: false, default: []
    
    # set up mapping
    mapping = {
      "Residential Community" => ["Residential", "Master Policy", "Rent Guarantee", "Security Deposit Replacement"],
      "Mixed Use Community" => ["Residential", "Master Policy", "Commercial", "Rent Guarantee", "Security Deposit Replacement"],
      "Commercial Community" => ["Commercial"],
      "Residential Unit" => ["Residential", "Master Policy Coverage", "Rent Guarantee", "Security Deposit Replacement"],
      "Commercial Unit" => ["Commercial"],
      "Small Business" => ["Commercial"],
      "Residential Building" => ["Residential", "Master Policy", "Rent Guarantee", "Security Deposit Replacement"]
    }
    pts = PolicyType.all.to_a
    mapping.transform_values!{|varr| varr.map{|v| pts.find{|pt| pt.title == v }&.id }.compact }
    # initialize stuff
    ::InsurableType.all.each do |it|
      it.update_columns(policy_type_ids: (mapping[it.title] || []))
    end
  end
  
  def down
    remove_column :insurable_types, :policy_type_ids
  end
end
