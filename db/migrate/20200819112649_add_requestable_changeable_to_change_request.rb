class AddRequestableChangeableToChangeRequest < ActiveRecord::Migration[5.2]
  def change
    add_column :change_requests, :changeable_type, :string
    add_column :change_requests, :requestable_id, :integer
    add_column :change_requests, :requestable_type, :string
    add_column :change_requests, :changeable_id, :integer
  end
end
