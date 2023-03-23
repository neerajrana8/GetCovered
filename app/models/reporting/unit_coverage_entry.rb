


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
      inverse_of: :unit_coverage_entry,
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
      lessee_ids = self.lease.nil? ? [] : self.lease.active_lease_users(lessee: true).pluck(:user_id).uniq
      self.lessee_count = lessee_ids.count
    end

    def generate!
      self.generate(bang: true)
    end
    
    def generate(bang: false)
      return if !self.coverage_status_exact.nil? # MOOSE WARNING: should probably introduce a stupid status column or something
      today = self.report_time.to_date
      # get lease user entries ready
      luces = []
      auditable_luces = []
      begin
        (self.lease&.active_lease_users(today, allow_future: true) || []).each do |alu|
          luce = (LeaseUserCoverageEntry.where(unit_coverage_entry: self, lease_user: alu).take || LeaseUserCoverageEntry.create!(unit_coverage_entry: self, lease_user: alu))
          if (self.lease.status == 'pending' || alu.is_current?(today))
            luces.push(luce)
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        raise # MOOSE WARNING: should respect bang probably...
      end
      auditable_luces = luces.select{|luce| luce.lessee && luce.current }
      # coverage_status_any
      self.coverage_status_any = luces.sort_by{|luce| COVERAGE_STATUSES_ORDER.find_index(luce.coverage_status_exact) }.first&.coverage_status_exact || "none"
      # coverage_status_exact
      self.coverage_status_exact = (
        if auditable_luces.all?{|luce| luce.coverage_status_exact == 'internal_or_external' }
          'internal_or_external'
        elsif auditable_luces.all?{|luce| ['internal_or_external', 'internal'].include?(luce.coverage_status_exact) }
          'internal'
        elsif auditable_luces.all?{|luce| ['internal_or_external', 'external'].include?(luce.coverage_status_exact) }
          'external'
        elsif auditable_luces.all?{|luce| ['internal_or_external', 'internal', 'external'].include?(luce.coverage_status_exact) }
          'internal_and_external'
        elsif auditable_luces.all?{|luce| ['master', 'internal_or_external', 'internal', 'external'].include?(luce.coverage_status_exact) }
          'master'
        else
          'none'
        end
      )
    end # end generate()


  end # end class
end
