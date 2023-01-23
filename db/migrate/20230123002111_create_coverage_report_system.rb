class CreateCoverageReportSystem < ActiveRecord::Migration[6.1]

  def change
    
    # coverage reports
    
    add_column :accounts, :reporting_coverage_reports_generate, :boolean, null: false, default: false
    add_column :accounts, :reporting_coverage_reports_settings, :jsonb, null: false, default: { 'coverage_determinant' => 'any' }
    add_index :accounts, :reporting_coverage_reports_generate, name: "index_accounts_on_rcrg"
    
    create_table :reporting_coverage_reports do |t|
      t.integer :status, null: false, default: 0
      t.integer :coverage_determinant, null: false
      t.datetime :report_time, null: true # also doubles as started_at
      t.datetime :completed_at, null: true
      t.boolean :visible, null: false, default: true
      
      t.jsonb :special, null: false, default: {}
      t.jsonb :error_data
      t.timestamps # nice to have I guess
      
      t.references :owner, polymorphic: true, null: true, index: false # better index below
    end
    add_index :reporting_coverage_reports, [:owner_type, :owner_id, :status, :report_time], name: "index_rcr_on_o_and_rt"
    
    create_table :reporting_coverage_entries do |t|
      t.string :reportable_category
      t.string :reportable_title
      t.string :reportable_description
      t.integer :status, null: false, default: 0 # created, generating, generated, errored
      
      t.integer :total_units, null: false, default: 0
      
      t.integer :total_units_unoccupied, null: false, default: 0
      t.integer :total_units_with_master_policy, null: false, default: 0
      t.integer :total_units_with_ho4_policy, null: false, default: 0
      t.integer :total_units_with_internal_policy, null: false, default: 0
      t.integer :total_units_with_external_policy, null: false, default: 0
      t.integer :total_units_with_no_policy, null: false, default: 0
      
      t.decimal :percent_units_unoccupied, precision: 5, scale: 2, null: false, default: 0
      t.decimal :percent_units_with_master_policy, precision: 5, scale: 2, null: false, default: 0
      t.decimal :percent_units_with_ho4_policy, precision: 5, scale: 2, null: false, default: 0
      t.decimal :percent_units_with_internal_policy, precision: 5, scale: 2, null: false, default: 0
      t.decimal :percent_units_with_external_policy, precision: 5, scale: 2, null: false, default: 0
      t.decimal :percent_units_with_no_policy, precision: 5, scale: 2, null: false, default: 0
      
      t.references :coverage_report # coverage_report_id column for a Reporting::CoverageReport id
      t.references :reportable, polymorphic: true, null: true # nil for global statistics
      t.references :parent, null: true, index: false
      t.jsonb :error_data
      # no timestamps
    end
    add_index :reporting_coverage_entries, [:coverage_report_id, :reportable_category, :parent_id, :reportable_type, :reportable_id], name: "index_rce_on_cri_rc_pi_rt_ri", unique: true
    
    
    create_table :reporting_unit_coverage_entries do |t|
      t.references :insurable
      t.datetime :report_time, null: false
      
      t.string :street_address, null: false
      t.string :unit_number, null: true
      t.string :yardi_id, null: true
      
      t.integer :coverage_status_exact # :none, :internal, :external, :master, :internal_and_external, :internal_or_external
      t.integer :coverage_status_numeric # :none, :internal, :external, :master, :internal_and_external, :internal_or_external
      t.integer :coverage_status_any # :none, :internal, :external, :master, :internal_and_external, :internal_or_external
      
      t.references :lease, null: true
      t.integer :lessee_count, null: false, default: 0
      t.string :lease_yardi_id, null: true
      t.jsonb :ho4_coverages, default: {}, null: false
      
      t.jsonb :error_info, null: true
      # no timestamps
    end
    add_index :reporting_unit_coverage_entries, [:report_time, :insurable_id], name: "index_ruce_on_rt_and_ii", unique: true
    add_index :reporting_unit_coverage_entries, [:report_time, :coverage_status_exact], name: "index_ruce_on_rt_and_cse", unique: false
    add_index :reporting_unit_coverage_entries, [:report_time, :coverage_status_numeric], name: "index_ruce_on_rt_and_csn", unique: false
    add_index :reporting_unit_coverage_entries, [:report_time, :coverage_status_any], name: "index_ruce_on_rt_and_css", unique: false
    add_index :reporting_unit_coverage_entries, [:report_time, :lessee_count], name: "index_ruce_on_rt_and_lc", unique: false
    
    create_table :reporting_coverage_entry_links do |t| # links from entries to unit entries
      t.references :parent
      t.references :child
      t.boolean :direct, null: false, default: true
    end
    add_index :reporting_coverage_entry_links, [:parent_id, :child_id], name: "index_rcel_on_pi_and_ci", unique: true
    
  end
end
