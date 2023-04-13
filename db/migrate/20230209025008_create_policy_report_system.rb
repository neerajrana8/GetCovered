class CreatePolicyReportSystem < ActiveRecord::Migration[6.1]
  def change
    create_table :reporting_policy_entries do |t|
      t.string :account_title
      t.string :number
      t.string :yardi_property
      t.string :community_title
      t.string :yardi_unit
      t.string :unit_title
      t.string :street_address
      t.string :city
      t.string :state
      t.string :zip
      t.string :carrier_title
      t.string :yardi_lease
      t.string :lease_status
      t.date :effective_date
      t.date :expiration_date
      t.references :account, index: false # we make better indices below
      t.references :policy
      t.references :lease
      t.references :community
      t.references :unit
      t.string :primary_policyholder_first_name
      t.string :primary_policyholder_last_name
      t.string :primary_policyholder_email
      t.string :primary_lessee_first_name
      t.string :primary_lessee_last_name
      t.string :primary_lessee_email
      t.string :any_lessee_email
      t.boolean :expires_before_lease
      t.boolean :applies_to_lessee
      
      t.timestamps
    end
    add_index :reporting_policy_entries, [:account_id, :expiration_date], name: "index_rpe_on_ai_and_ed"
    add_index :reporting_policy_entries, [:account_id, :community_title, :expiration_date], name: "index_rpe_on_ai_and_ct_and_ed"
  end
end
