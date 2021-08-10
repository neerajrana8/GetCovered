class AddTagIdsToPolicyApplications < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :tag_ids, :bigint, array: true, null: false, default: []
    add_index :policy_applications, :tag_ids, name: "policy_application_tag_ids_index", using: :gin
  end
end
