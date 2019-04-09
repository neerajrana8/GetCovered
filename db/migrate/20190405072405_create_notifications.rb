class CreateNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :notifications do |t|
      t.string :subject
      t.text :message
      t.integer :status, default: 0
      t.integer :delivery_method, default: 0
      t.integer :code, default: 0
      t.integer :action, default: 0
      t.integer :template, default: 0
      t.references :notifiable, 
        polymorphic: true

      t.timestamps
    end
  end
end
