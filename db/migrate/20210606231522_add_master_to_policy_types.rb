class AddMasterToPolicyTypes < ActiveRecord::Migration[5.2]
  def up
    add_column :policy_types, :master, :boolean, default: false
    add_column :policy_types, :master_coverage, :boolean, default: false
    add_column :policy_types, :master_policy_id, :integer, index: true, default: nil
    add_foreign_key :policy_types, :policy_types, column: :master_policy_id

    PolicyType.find_by(title: 'Master Policy')&.update(master: true)
    PolicyType.find_by(title: 'Master Policy Coverage')&.update(master_coverage: true, master_policy_id: PolicyType::MASTER_ID)
  end
  
  def down
    remove_column :policy_types, :master
    remove_column :policy_types, :master_coverage
    remove_column :policy_types, :master_policy_id
  end
end
