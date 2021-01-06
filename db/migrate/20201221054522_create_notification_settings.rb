class CreateNotificationSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :notification_settings do |t|
      t.string :action
      t.boolean :enabled, null: false, default: false

      t.references :notifyable, polymorphic: true, index: { name: 'notification_settings_notifyable_index' }

      t.timestamps
    end
    add_index :notification_settings, :action
  end
end
