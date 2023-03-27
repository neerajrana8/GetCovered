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
      t.integer :coverage_status_any # :none, :internal, :external, :master, :internal_and_external, :internal_or_external
      t.string :lease_yardi_id, null: true
      t.boolean :occupied, null: true
      
      t.references :primary_lease_coverage_entry, null: true, index: false # stupid name nonsense
      
      t.jsonb :error_info, null: true
      # no timestamps
    end
    add_index :reporting_unit_coverage_entries, [:report_time, :insurable_id], name: "index_ruce_on_rt_and_ii", unique: true
    add_index :reporting_unit_coverage_entries, [:report_time, :coverage_status_exact], name: "index_ruce_on_rt_and_cse", unique: false
    add_index :reporting_unit_coverage_entries, [:report_time, :coverage_status_any], name: "index_ruce_on_rt_and_css", unique: false
    add_index :reporting_unit_coverage_entries, [:report_time, :occupied], name: "index_ruce_on_o", unique: false
    add_index :reporting_unit_coverage_entries, :primary_lease_coverage_entry_id, name: "index_ruce_on_plcei", unique: false
    
    create_table :reporting_coverage_entry_links do |t| # links from entries to unit entries
      t.references :parent
      t.references :child
      t.boolean :direct, null: false, default: true
    end
    add_index :reporting_coverage_entry_links, [:parent_id, :child_id], name: "index_rcel_on_pi_and_ci", unique: true

    create_table :reporting_lease_coverage_entries do |t|
      t.datetime :report_time, null: false
      t.references :account, null: true, index: false # too long
      t.references :unit_coverage_entry, null: false, index: false # too long
      t.references :lease, null: false
      t.integer :status, null: false
      t.integer :lessee_count, null: false, default: 0
      t.string :yardi_id
      t.integer :coverage_status_exact
      t.integer :coverage_status_any
    end
    add_index :reporting_lease_coverage_entries, [:report_time, :lease_id], name: "index_rlce_on_rt_and_li", unique: true
    add_index :reporting_lease_coverage_entries, [:account_id, :report_time], name: "index_rlce_on_a_and_rt", unique: false
    add_index :reporting_lease_coverage_entries, :unit_coverage_entry_id, name: "index_lce_on_ucei", unique: false

    create_table :reporting_lease_user_coverage_entries do |t|
      t.datetime :report_time, null: false
      t.references :account, index: false # too long
      
      t.references :lease_user, index: false, index: false # too long
      t.datetime :report_time, null: false
      
      t.boolean :lessee, null: false
      t.boolean :current, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: true
      t.string :yardi_id, null: true
      
      t.references :policy, null: true
      t.string :policy_number, null: true
      
      t.integer :coverage_status_exact, null: false
      
      t.references :lease_coverage_entry, index: false # too long
    end
    add_index :reporting_lease_coverage_entries, [:report_time, :lease_user_id], name: "index_rluce_on_rt_and_lui", unique: true
    add_index :reporting_lease_user_coverage_entries, :lease_coverage_entry_id, name: "index_rluce_on_lce_id", unique: false
    add_index :reporting_lease_user_coverage_entries, [:account_id, :report_time], name: "index_rluce_on_uce_ai)and_rt", unique: false
    add_index :reporting_lease_user_coverage_entries, :lease_user_id, name: "index_rluce_on_uce_lui", unique: false
    
    
  end
end
