class FixPoliciesCancellationDate < ActiveRecord::Migration[6.1]
  def change
    add_column :policies, :fixed_cancellation_date, :date, null: true
    Policy.where.not(cancellation_date: nil).each do |pol|
      pol.update_columns(fixed_cancellation_date: Date.parse(pol.cancellation_date))
    end
    remove_column :policies, :cancellation_date
    rename_column :policies, :fixed_cancellation_date, :cancellation_date
  end
end
