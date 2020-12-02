class AddErrorMessageToPolicyApplication < ActiveRecord::Migration[5.2]
  def change
    add_column :policy_applications, :error_message, :string
  end
end
