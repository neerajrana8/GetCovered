class AddToAccount < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :payment_profile_stripe_id, :string
    add_column :accounts, :current_payment_method, :integer
    remove_column :staffs, :current_payment_method, :integer
    remove_column :staffs, :stripe_id, :string
  end
end
