


module Reporting
  class UnitCoverageEntry < ApplicationRecord
    self.table_name = "reporting_unit_coverage_entries"
    include Reporting::CoverageDetermining # provides COVERAGE_STATUSES enum setup
    
    belongs_to :insurable
    belongs_to :account
    belongs_to :lease, optional: true
    belongs_to :primary_lease_coverage_entry, optional: true,
      class_name: "Reporting::LeaseCoverageEntry",
      foreign_key: :primary_lease_coverage_entry_id
    
    has_many :links,
      class_name: "Reporting::CoverageEntryLink",
      inverse_of: :child,
      foreign_key: :child_id
    has_many :parents,
      class_name: "Reporting::CoverageEntry",
      through: :links,
      source: :parent
    has_many :lease_coverage_entries,
      class_name: "Reporting::LeaseCoverageEntry",
      inverse_of: :unit_coverage_entry,
      foreign_key: :unit_coverage_entry_id
    has_many :lease_user_coverage_entries,
      class_name: "Reporting::LeaseUserCoverageEntry",
      through: :lease_coverage_entries,
      source: :lease_user_coverage_entries
      
    before_create :prepare
    
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
    
    # only :report_time and :insurable need to be provided by the user
    def prepare
      # basic setup
      today = self.report_time.to_date
      self.account_id = self.insurable.account_id
      self.street_address ||= self.insurable.primary_address&.full || ""
      self.unit_number ||= self.insurable.title
      self.yardi_id ||= self.insurable.integration_profiles.where("external_context ILIKE '%unit_in_community_%'").take&.external_id
    end

    def generate!
      self.generate(bang: true)
    end
    
    def generate(bang: false)
      return if !self.coverage_status_exact.nil? # means we haven't run generate! yet
      today = self.report_time.to_date
      # get lease entries ready
      self.insurable.leases.where(defunct: false).where.not(status: 'expired').where.not(id: self.lease_coverage_entries.pluck(:lease_id)).each do |mister_lease|
        begin
          lce = self.lease_coverage_entries.where(lease: mister_lease).take || self.lease_coverage_entries.create!(lease: mister_lease)
          lce.generate!
        rescue StandardError => e
          raise # MOOSE WARNING: respect the bang, fool!
        end
      end
      # set stuff
      self.primary_lease_coverage_entry = self.lease_coverage_entries.reload.where(lease_id: self.insurable.latest_lease&.id).take
      self.lease_yardi_id = self.primary_lease_coverage_entry&.yardi_id
      self.coverage_status_exact = self.primary_lease_coverage_entry ? self.primary_lease_coverage_entry.coverage_status_exact : 'none'
      self.coverage_status_any = self.primary_lease_coverage_entry ? self.primary_lease_coverage_entry.coverage_status_any : 'none'
      self.coverage_status = self.send("coverage_status_#{self.account&.reporting_coverage_reports_settings&.[]('coverage_determinant') || 'any'}")
      self.occupied = (!self.primary_lease_coverage_entry.nil? && self.primary_lease_coverage_entry.lessee_count != 0)
      # done!
      bang ? self.save! : self.save
    end # end generate()


  end # end class
end
