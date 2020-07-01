class RenameActionToCustomizedActionToChangeRequests < ActiveRecord::Migration[5.2]
  def change
    rename_column :change_requests, :action, :customized_action
  end
end
