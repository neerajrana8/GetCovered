class CreateLeads < ActiveRecord::Migration[5.2]
  def change
    create_table :leads do |t|
      t.string     :email, uniqueness: true
      t.string     :identifier, uniqueness: true
      t.references :user
      t.string     :labels, array: true

      t.timestamps
    end

    add_index :leads, :email
    add_index :leads, :user_id
  end
end
