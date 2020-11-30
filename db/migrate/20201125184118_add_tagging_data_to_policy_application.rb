class AddTaggingDataToPolicyApplication < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :tagging_data, :jsonb
  end
end
