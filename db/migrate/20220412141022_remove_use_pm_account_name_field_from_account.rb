class RemoveUsePmAccountNameFieldFromAccount < ActiveRecord::Migration[6.1]
  def change
    remove_column :accounts, :use_pm_account_name
  end
end
