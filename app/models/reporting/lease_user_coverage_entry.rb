module Reporting
  class LeaseUserCoverageEntry < ApplicationRecord
    self.table_name = "reporting_lease_user_coverage_entries"
    include Reporting::CoverageDetermining # provides COVERAGE_STATUSES enum setup
    
    belongs_to :lease_user
    belongs_to :lease_coverage_entry,
      class_name: "Reporting::LeaseCoverageEntry",
      foreign_key: :lease_coverage_entry_id,
      inverse_of: :lease_user_coverage_entries
    belongs_to :account
    belongs_to :policy,
      optional: true
    
    before_validation :set_account,
      on: :create
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
    
    def set_account
      self.account_id ||= self.lease_user.lease.account_id
    end

    def prepare # only lease_coverage_entry and lease_user need to be provided
      self.report_time = self.lease_coverage_entry.unit_coverage_entry.report_time
      lease = self.lease_user.lease
      
      self.account_id = self.lease_user.lease.account_id
      self.lessee = self.lease_user.lessee
      self.current = self.lease_user.is_current?(self.report_time.to_date)
      
      self.first_name = self.lease_user.user&.profile&.first_name || "Unknown"
      self.last_name = self.lease_user.user&.profile&.last_name || "Unknown"
      self.email = self.lease_user.user&.email || self.lease_user.user&.profile&.contact_email
      self.yardi_id = self.lease_user.integration_profiles.references(:integrations).includes(:integration).where(
        integrations: { integratable_type: "Account", integratable_id: self.account_id, provider: 'yardi' }
      ).take&.external_id
      
      policies = lease.matching_policies(users: self.lease_user.user_id, policy_type_id: [::PolicyType::RESIDENTIAL_ID, ::PolicyType::MASTER_COVERAGE_ID]).order("expiration_date desc")
      self.policy = policies.find{|p| p.policy_type_id == ::PolicyType::RESIDENTIAL_ID } || policies.find{|p| p.policy_type_id == ::PolicyType::MASTER_COVERAGE_ID }
      self.policy_number = policy&.number
      
      self.coverage_status_exact =
        if self.policy.nil?
          :none
        elsif self.policy&.policy_type_id == ::PolicyType::MASTER_COVERAGE_ID
          :master
        else
          if policies.any?{|p| p.policy_type_id == ::PolicyType::RESIDENTIAL_ID && p.policy_in_system }
            if policies.any?{|p| p.policy_type_id == ::PolicyType::RESIDENTIAL_ID && !p.policy_in_system }
              :internal_or_external
            else
              :internal
            end
          else 
            :external
          end
        end
      ;
      # all done
      
    end


  end # end class
end
