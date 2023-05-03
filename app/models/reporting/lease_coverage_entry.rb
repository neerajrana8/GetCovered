


module Reporting
  class LeaseCoverageEntry < ApplicationRecord
    self.table_name = "reporting_lease_coverage_entries"
    include Reporting::CoverageDetermining # provides COVERAGE_STATUSES enum setup
      
    belongs_to :lease
    
    belongs_to :account
    
    belongs_to :unit_coverage_entry,
      class_name: "Reporting::UnitCoverageEntry",
      inverse_of: :lease_coverage_entries,
      foreign_key: :unit_coverage_entry_id
    
    has_many :lease_user_coverage_entries,
      class_name: "Reporting::LeaseUserCoverageEntry",
      inverse_of: :lease_coverage_entry,
      foreign_key: :lease_coverage_entry_id
    
    before_validation :prepare,
      on: :create
    
    enum status: ::Lease.statuses,
      _prefix: true
    enum coverage_status_any: COVERAGE_STATUSES,
      _prefix: true
    enum coverage_status_exact: COVERAGE_STATUSES,
      _prefix: true
    enum coverage_status: COVERAGE_STATUSES,
      _prefix: true

    def get_coverage_status(determinant: nil, expand_ho4: false, simplify: true)
      tr = determinant.nil? || determinant == 'mixed' ? self.coverage_status : self.send("coverage_status_#{determinant}")
      tr = 'internal' if (simplify || !expand_ho4) && (tr == 'internal_and_external' || tr == 'internal_or_external')
      tr = 'ho4' if !expand_ho4 && (tr == 'internal' || tr == 'external')
      return tr
    end
    
    # only :unit_coverage_entry_id and :lease_id need to be provided by the user
    def prepare
      self.report_time = self.unit_coverage_entry.report_time
      self.account_id = self.lease.account_id
      self.yardi_id = self.lease.integration_profiles.references(:integrations).includes(:integration).where(
        integrations: { integratable_type: "Account", integratable_id: self.lease.account_id },
        external_context: "lease"
      ).take&.external_id
      self.status = self.lease.status
      self.start_date = self.lease.start_date
      self.end_date = self.lease.end_date
      self.lessee_count = self.lease.active_lease_users(self.unit_coverage_entry.report_time.to_date, lessee: true).count || 0
    end

    def generate!
      self.generate(bang: true)
    end
    
    def generate(bang: false)
      return if !self.coverage_status_exact.nil? # MOOSE WARNING: should probably introduce a stupid status column or something
      today = self.unit_coverage_entry.report_time.to_date
      # get lease user entries ready
      luces = []
      auditable_luces = []
      (self.lease.active_lease_users(today, allow_future: true) || []).each do |alu|
        begin
          luce = (LeaseUserCoverageEntry.where(lease_coverage_entry: self, lease_user: alu).take || LeaseUserCoverageEntry.create!(lease_coverage_entry: self, lease_user: alu))          
          luces.push(luce)
        rescue ActiveRecord::RecordInvalid => e
          raise # MOOSE WARNING: should respect bang probably...
        end
      end
      auditable_luces = luces.select{|luce| luce.lessee && (self.status == 'pending' || luce.current) }
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
      # coverage_status
      self.coverage_status = self.send("coverage_status_#{self.account&.reporting_coverage_reports_settings&.[]('coverage_determinant') || 'any'}")
      # done
      bang ? self.save! : self.save
    end # end generate()


  end # end class
end
