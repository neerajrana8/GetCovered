class CreateInvoices < ActiveRecord::Migration[5.2]
  def change
    create_table :invoices do |t|
      t.string        :number
      t.integer       :status, default: 0
      t.datetime      :status_changed
      t.text          :description
      t.date          :due_date
      t.date          :available_date
      t.date          :term_first_date
      t.date          :term_last_date
      t.integer       :renewal_cycle, default: 0
      t.integer       :total, default: 0
      t.integer       :subtotal, default: 0
      t.integer       :tax, default: 0
      t.decimal       :tax_percent, precision: 5, scale: 2, default: 0.0
      t.jsonb         :system_data, default: {}
      t.integer       :amount_refunded, default: 0
      t.integer       :amount_to_refund_on_completion, default: 0
      t.boolean       :has_pending_refund, default: false
      t.jsonb         :pending_refund_data, default: {}
      t.references    :user, index: true

      t.timestamps
    end
  end
end
