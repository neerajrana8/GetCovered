class AddDependencySystemToScheduledActions < ActiveRecord::Migration[6.1]
  def change
    add_column :scheduled_actions, :prerequisite_ids, :bigint, array: true, null: false, default: []
    change_column_null :scheduled_actions, :trigger_time, true
  end
end
