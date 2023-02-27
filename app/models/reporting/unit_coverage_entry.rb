


module Reporting
  class UnitCoverageEntry < ApplicationRecord
    self.table_name = "reporting_unit_coverage_entries"
    include Reporting::CoverageDetermining # provides COVERAGE_STATUSES enum setup
    
    belongs_to :insurable
    belongs_to :lease, optional: true
    
    has_many :links,
      class_name: "Reporting::CoverageEntryLink",
      inverse_of: :child,
      foreign_key: :child_id
    has_many :parents,
      class_name: "Reporting::CoverageEntry",
      through: :links,
      source: :parent
    has_many :lease_user_coverage_entries,
      class_name: "Reporting::LeaseUserCoverageEntry",
      inverse_of :unit_coverage_entry,
      foreign_key: :unit_coverage_entry_id
      
    before_create :prepare
    
    enum coverage_status_any: COVERAGE_STATUSES,
      _prefix: true
    enum coverage_status_numeric: COVERAGE_STATUSES,
      _prefix: true
    enum coverage_status_exact: COVERAGE_STATUSES,
      _prefix: true

    def coverage_status(determinant, expand_ho4: false, simplify: true)
      tr = self.send("coverage_status_#{determinant}")
      tr = 'internal' if (simplify || !expand_ho4) && (tr == 'internal_and_external' || tr == 'internal_or_external')
      tr = 'ho4' if !expand_ho4 && (tr == 'internal' || tr == 'external')
      return tr
    end
    def covered_by_master_policy(determinant)
      'master' == self.send("coverage_status_#{determinant}")
    end
    def covered_by_ho4_policy(determinant)
      ['internal', 'external', 'internal_and_external', 'internal_or_external'].include?(self.send("coverage_status_#{determinant}"))
    end
    def covered_by_internal_policy(determinant)
      ['internal', 'internal_and_external', 'internal_or_external'].include?(self.send("coverage_status_#{determinant}"))
    end
    def covered_by_external_policy(determinant)
      'external' == self.send("coverage_status_#{determinant}")
    end
    def covered_by_no_policy(determinant)
      'none' == self.send("coverage_status_#{determinant}")
    end
    
    # only :report_time and :insurable need to be provided by the user
    def prepare
      # basic setup
      today = self.report_time.to_date
      self.street_address ||= self.insurable.primary_address&.full || ""
      self.unit_number ||= self.insurable.title
      self.yardi_id ||= self.insurable.integration_profiles.where("external_context ILIKE '%unit_in_community_%'").take&.external_id
      self.lease_id ||= self.insurable.leases.current.order(start_date: :desc, created_at: :desc).first&.id
      self.lease_yardi_id ||= self.lease&.integration_profiles&.where(external_context: 'lease')&.take&.external_id
      lessee_ids = self.lease.nil? ? [] : self.lease.lease_users.where(lessee: true, moved_out_at: nil).or(self.lease.lease_users.where(lessee: true, moved_out_at: (today + 1.day)...)).pluck(:user_id).uniq
      self.lessee_count ||= lessee_ids.count
    end

    def generate!
      self.generate(bang: true)
    end
    
    def generate(bang: false)
      today = self.report_time.to_date
      # prepare for coverage_statuses
      time_query = self.insurable.policies.where(expiration_date: nil).or(self.insurable.policies.where(expiration_date: (today + 1.day)...))
      time_query = time_query.where(cancellation_date: nil).or(time_query.where(cancellation_date: (today + 1.day)...))
      time_query = time_query.where("effective_date <= ?", today)
      mpc = time_query.where(policy_type_id: ::PolicyType::MASTER_COVERAGES_IDS, status: "BOUND")
      ho4 = time_query.where(policy_type_id: ::PolicyType::RESIDENTIAL_ID, status: ::Policy.active_statuses)
      internal = []
      external = []
      ho4.each{|p| (p.in_system? ? internal : external).push(p) }
      self.ho4_coverages = {
        'ulu_lexicon' => self.lease&.lease_users&.map{|lu| [lu.user_id, lu.id] }, # so it's possible to reconstruct internal/external from LUs in case user mergers break the IDs
        'internal' => PolicyUser.where(policy: internal).pluck(:user_id).uniq.sort.to_a, # already an array, but paranoia > efficiency
        'external' => PolicyUser.where(policy: external).pluck(:user_id).uniq.sort.to_a,
      }
      self.ho4_coverages['none'] = lessee_ids - (self.ho4_coverages['internal'] | self.ho4_coverages['external'])
      # coverage_status_any
      self.coverage_status_any = if ho4.blank? || self.lessee_count == 0
          mpc.blank? ? 'none' : 'master'
        elsif !internal.blank?
          external.blank? ? 'internal' : 'internal_or_external'
        else
          'external'
      end
      # coverage_status_numeric
      self.coverage_status_numeric = case ['internal', 'external'].map{|pss| self.lessee_count > 0 && ho4_coverages[pss].count >= self.lessee_count }
        when [true, true]
          'internal_or_external'
        when [true, false]
          'internal'
        when [false, true]
          'external'
        when [false, false]
          if self.lessee_count > 0 && (ho4_coverages['internal'] | ho4_coverages['external']).count >= self.lessee_count
            'internal_and_external'
          elsif !mpc.blank?
            'master'
          else
            'none'
          end
      end
      # coverage_status_exact
      self.coverage_status_exact = case ['internal', 'external'].map{|pss| self.lessee_count > 0 && (lessee_ids - ho4_coverages[pss]).count == 0 }
        when [true, true]
          'internal_or_external'
        when [true, false]
          'internal'
        when [false, true]
          'external'
        when [false, false]
          if self.lessee_count > 0 && (lessee_ids - (ho4_coverages['internal'] | ho4_coverages['external'])).count == 0
            'internal_and_external'
          elsif !mpc.blank?
            'master'
          else
            'none'
          end
      end
    end # end generate()


  end # end class
end
