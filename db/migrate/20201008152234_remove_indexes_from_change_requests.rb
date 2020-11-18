class RemoveIndexesFromChangeRequests < ActiveRecord::Migration[5.2]
  def up
    remove_index :change_requests, name: :index_change_requests_on_customized_action
    remove_index :change_requests, name: :index_change_requests_on_status
  end

  def down

  end
end
