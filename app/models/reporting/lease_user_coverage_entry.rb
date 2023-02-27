module Reporting
  class LeaseUserCoverageEntry < ApplicationRecord
    self.table_name = "reporting_lease_user_coverage_entries"
    include Reporting::CoverageDetermining # provides COVERAGE_STATUSES enum setup
    
    belongs_to :lease_user
    belongs_to :unit_coverage_entry,
      class_name: "Reporting::UnitCoverageEntry",
      foreign_key: :unit_coverage_entry_id
    belongs_to :account
    belongs_to :policy,
      optional: true
      
    before_create :prepare
    
    enum coverage_status_exact: COVERAGE_STATUSES,
      _prefix: true

    def coverage_status(expand_ho4: false, simplify: true)
      tr = self.send("coverage_status_exact")
      tr = 'internal' if (simplify || !expand_ho4) && (tr == 'internal_and_external' || tr == 'internal_or_external')
      tr = 'ho4' if !expand_ho4 && (tr == 'internal' || tr == 'external')
      return tr
    end
    def covered_by_master_policy
      'master' == self.send("coverage_status_exact")
    end
    def covered_by_ho4_policy
      ['internal', 'external', 'internal_and_external', 'internal_or_external'].include?(self.send("coverage_status_exact"))
    end
    def covered_by_internal_policy
      ['internal', 'internal_and_external', 'internal_or_external'].include?(self.send("coverage_status_exact"))
    end
    def covered_by_external_policy
      'external' == self.send("coverage_status_exact")
    end
    def covered_by_no_policy
      'none' == self.send("coverage_status_exact")
    end

    def prepare # only unit_coverage_entry and lease_user need to be provided
      self.account_id = self.lease_user.lease.account_id
      
      self.report_time = self.unit_coverage_entry.report_time
      lease = self.lease_user.lease
      self.lease_yardi_id = self.lease.integration_profiles.references(:integrations).includes(:integration).where(
        integrations: { integratable_type: "Account", integratable_id: self.account_id, provider: 'yardi' },
        external_context: "lease"
      ).take&.external_id
      
      self.first_name = self.lease_user.user&.profile&.first_name || "Unknown"
      self.last_name = self.lease_user.user&.profile&.last_name || "Unknown"
      self.email = self.lease_user.user&.email || self.lease_user.user&.profile&.contact_email
      self.yardi_id = self.lease_user.integration_profiles.references(:integrations).includes(:integration).where(
        integrations: { integratable_type: "Account", integratable_id: self.account_id, provider: 'yardi' }
      ).take&.external_id
      
      self.policy =  #################################################################################################################################################################################
      
      
      
      t.integer :coverage_status_exact, null: false
      t.references :policy, null: true
      t.string :policy_number, null: true
      
    end


  end # end class
end
