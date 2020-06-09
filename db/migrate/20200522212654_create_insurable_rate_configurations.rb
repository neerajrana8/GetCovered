class CreateInsurableRateConfigurations < ActiveRecord::Migration[5.2]
  def change
    create_table :insurable_rate_configurations do |t|
      t.jsonb :carrier_info,
        null: false,
        default: {}
      t.jsonb :coverage_options,
        null: false,
        default: []
      t.jsonb :rules,
        null: false,
        default: []
      
      t.references :configurable,
        polymorphic: true
      t.references :configurer,
        polymorphic: true
      t.references :carrier_insurable_type
      t.timestamps
    end
  end
end
