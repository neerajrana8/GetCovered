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
        default: {}
      
      t.references :configurable,
        polymorphic: true,
        index: { name: :index_irc_configurable }
      t.references :configurer,
        polymorphic: true,
        index: { name: :index_irc_configurer }
      t.references :carrier_insurable_type,
        index: { name: :index_irc_cit }
      t.timestamps
    end
  end
end
