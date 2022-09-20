class AddBodyToContactRecord < ActiveRecord::Migration[6.1]
  def change
    add_column :contact_records, :body, :text
    add_column :contact_records, :source, :string, default: "System Mails"
    add_column :contact_records, :thread_id, :string, default: "0000"
    add_column :contact_records, :subject, :string
  end
end
