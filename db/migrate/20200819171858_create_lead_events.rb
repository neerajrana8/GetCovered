class CreateLeadEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :lead_events do |t|
      t.jsonb :data
      t.string :tag
      t.float :latitude
      t.float :longitude

      t.references :lead

      t.timestamps
    end
  end
end
