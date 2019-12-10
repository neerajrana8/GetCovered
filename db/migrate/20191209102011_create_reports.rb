class CreateReports < ActiveRecord::Migration[5.2]
  def change
    create_table :reports do |t|
      t.integer :format
      t.integer :duration
      t.datetime :range_start
      t.datetime :range_end
      t.jsonb :data
      t.references :reportable,
                   polymorphic: true

      t.timestamps
    end
    add_index :reports, [ :reportable_type, :reportable_id, :created_at ],
              name: 'reports_index'
  end
end
