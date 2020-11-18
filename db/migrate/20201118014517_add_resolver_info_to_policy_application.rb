class AddResolverInfoToPolicyApplication < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :resolver_info, :jsonb, null: true, default: nil
  end
end
