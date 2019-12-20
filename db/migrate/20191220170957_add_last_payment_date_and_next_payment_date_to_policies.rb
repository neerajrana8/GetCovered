class AddLastPaymentDateAndNextPaymentDateToPolicies < ActiveRecord::Migration[5.2]
  def change
    add_column :policies, :last_payment_date, :date
    add_column :policies, :next_payment_date, :date
  end
end
