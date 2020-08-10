class UpgradePolicyCancellationColumns < ActiveRecord::Migration[5.2]
  def up
    add_column :policies, :cancellation_reason
    remove_column :policies, :cancellation_code
    
    rename_column :policies, :cancellation_date_date, :cancellation_date
  end
  
  def down
    rename_column :policies, :cancellation_date, :cancellation_date_date
  
    add_column :policies, :cancellation_code
    remove_column :policies, :cancellation_reason
  end
end
