class AddMissingTrackable < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string

    add_column :staffs, :sign_in_count, :integer, default: 0, null: false
    add_column :staffs, :current_sign_in_at, :datetime
    add_column :staffs, :last_sign_in_at, :datetime
    add_column :staffs, :current_sign_in_ip, :string
    add_column :staffs, :last_sign_in_ip, :string

    add_column :super_admins, :sign_in_count, :integer, default: 0, null: false
    add_column :super_admins, :current_sign_in_at, :datetime
    add_column :super_admins, :last_sign_in_at, :datetime
    add_column :super_admins, :current_sign_in_ip, :string
    add_column :super_admins, :last_sign_in_ip, :string

  end
end
