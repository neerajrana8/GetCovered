
module Reporting
  class CoverageEntry < ApplicationRecord
    self.table_name = "reporting_coverage_entries"
    #include Reporting::CoverageDetermining # provides COVERAGE_DETERMINANTS enum setup
    
    belongs_to :coverage_report,
      class_name: "Reporting::CoverageReport",
      inverse_of: :coverage_entries,
      foreign_key: :coverage_report_id

    belongs_to :reportable,
      polymorphic: true,
      optional: true

    belongs_to :parent,
      class_name: "Reporting::CoverageEntry",
      inverse_of: :children,
      foreign_key: :parent_id,
      optional: true

    has_many :children,
      class_name: "Reporting::CoverageEntry",
      inverse_of: :parent,
      foreign_key: :parent_id

    has_many :links,
      class_name: "Reporting::CoverageEntryLink",
      inverse_of: :parent,
      foreign_key: :parent_id

    has_many :unit_coverage_entries,
      class_name: "Reporting::UnitCoverageEntry",
      through: :links,
      source: :child

    has_many :lease_user_coverage_entries,
      class_name: "Reporting::LeaseUserCoverageEntry",
      through: :unit_coverage_entries,
      source: :lease_user_coverage_entries

    before_create :prepare
    before_save :set_derived_statistics
    
    validates_uniqueness_of :reportable_id, scope: [:coverage_report_id, :reportable_category, :parent_id, :reportable_type]

    enum status: {
      created: 0,
      generating: 1,
      generated: 2,
      errored: 3
    }
    
    def prepare(repeat: false)
      return unless self.id.nil? && (@prepared.nil? || repeat)
      @prepared = true
      ownership_constraint = case self.coverage_report.owner_type
        when 'Account'
          [:where, { account_id: self.coverage_report.owner_id }]
        when 'Agency'
          [:where, { account_id: Account.where(agency_id: [self.coverage_report.owner_id] + self.coverage_report.owner.agencies.pluck(:id)).select(:id) }]
        when nil
          [:itself]
        else
          [:where, { id: 0 }]
      end
      # do per-model logic
      if self.reportable_type == "Insurable"
        if InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(self.reportable.insurable_type_id)
          self.reportable_category = "Building"
          self.reportable_title = self.reportable.title
          self.reportable_description = self.reportable.primary_address.combined_street_address
        elsif InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(self.reportable.insurable_type_id)
          self.reportable_category = "Community"
          self.reportable_title = self.reportable.title
          self.reportable_description = self.reportable.primary_address.full
        else
          raise StandardError.new("Only residential buildings/communities are supported!")
        end
      elsif self.reportable_type == 'IntegrationProfile'
        if self.reportable.profileable_type == 'Insurable' && self.reportable.external_context == 'community'
          self.reportable_category = "Yardi Property"
          self.reportable_title = self.reportable.external_id
          self.reportable_description = self.reportable.profileable.title
        else
          raise StandardError.new("Only community integration profiles are supported!")
        end
      elsif self.reportable_type == 'InsurableGeographicalCategory'
        self.reportable_category = "State"
        self.reportable_title = self.reportable.state
        self.reportable_description = nil
        unless self.reportable.pure_state?
          raise StandardError.new("Only InsurableGeographicalCategories for entire states are supported!")
        end
      elsif self.reportable_type == 'Account'
        self.reportable_category = "PM Account"
        self.reportable_title = self.reportable.title
        self.reportable_description = nil
      elsif self.reportable_type.nil?
        self.reportable_category = "Universe"
        self.reportable_title = "Get Covered System"
        self.reportable_description = nil
      end # end per-model logic
    end # end method
    
    def generate!
      self.generate(bang: true)
    end

    def generate(bang: false)
      return nil unless self.status == 'created'
      to_return = nil
      begin
        self.update!(status: 'generating')
        ActiveRecord::Base.transaction(requires_new: true) do
          # initialize totals to 0
          self.total_units = 0
          self.total_units_with_master_policy = 0
          self.total_units_with_internal_policy = 0
          self.total_units_with_external_policy = 0
          self.total_units_with_ho4_policy = 0
          self.total_units_with_no_policy = 0
          # do per-model logic
          if self.reportable_type == 'Insurable'
            if InsurableType::RESIDENTIAL_BUILDINGS_IDS.include?(self.reportable.insurable_type_id)
              # buildings
              # generate unit entries
              generate_unit_entries(
                Insurable.confirmed.where(insurable_id: self.reportable_id, insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS)
                                   .where.not(id: Reporting::UnitCoverageEntry.where(report_time: self.coverage_report.report_time).select(:insurable_id))
                                   .send(*self.ownership_constraint)
                                   .pluck(:id)
              )
              # generate links
              Reporting::CoverageEntryLink.try_insert_all(Reporting::UnitCoverageEntry.where(
                report_time: self.coverage_report.report_time,
                insurable_id: self.reportable.units.confirmed.send(*self.ownership_constraint).select(:id)
              ).pluck(:id).map{|uce_id| { parent_id: self.id, child_id: uce_id, direct: true } })
              # accumulate
              self.accumulate_units
            elsif InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(self.reportable.insurable_type_id)
              # communities
              # generate building entries
              ids = Insurable.confirmed.where(insurable_id: self.reportable_id, insurable_type_id: InsurableType::RESIDENTIAL_BUILDINGS_IDS)
                                       .send(*self.ownership_constraint)
                                       .pluck(:id)
              ids.each do |id|
                found = Insurable.find(id)
                created = begin
                  Reporting::CoverageEntry.create!(parent: self, reportable_category: "Building", coverage_report: self.coverage_report, reportable: found)
                rescue ActiveRecord::RecordInvalid => e
                  raise unless (e.record.errors.to_hash.all?{|k,v| v == "has already been taken" } rescue false)
                  nil # we just ignore this error, we're apparently in what would with locks be a race condition and someone else created it first, but so what?
                end
                created&.generate!
              end
              ids.clear
              # generate unit entries
              generate_unit_entries(
                Insurable.confirmed.where(insurable_id: self.reportable_id, insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS)
                                   .where.not(id: Reporting::UnitCoverageEntry.where(report_time: self.coverage_report.report_time).select(:insurable_id))
                                   .where.not(account_id: nil)
                                   .send(*self.ownership_constraint)
                                   .pluck(:id)
              )
              # generate links
              Reporting::CoverageEntryLink.try_insert_all(Reporting::UnitCoverageEntry.where(
                report_time: self.coverage_report.report_time,
                insurable_id: self.reportable.units.confirmed.where(insurable_id: self.reportable_id).send(*self.ownership_constraint).select(:id)
              ).pluck(:id).map{|uce_id| { parent_id: self.id, child_id: uce_id, direct: true } })
              Reporting::CoverageEntryLink.try_insert_all(Reporting::UnitCoverageEntry.where(
                report_time: self.coverage_report.report_time,
                insurable_id: self.reportable.units.confirmed.where.not(insurable_id: self.reportable_id).send(*self.ownership_constraint).select(:id)
              ).pluck(:id).map{|uce_id| { parent_id: self.id, child_id: uce_id, direct: false } })
              # accumulate
              self.accumulate_children(category: "Building")
              self.accumulate_units(direct: true)
            else
              raise StandardError.new("Only residential buildings/communities are supported!")
            end
          elsif self.reportable_type == 'IntegrationProfile'
            if self.reportable.profileable_type == 'Insurable' && self.reportable.external_context == 'community'
              # yardi communities
              # generate unit entries
              generate_unit_entries(
                self.reportable.profileable.units.confirmed.where(insurable_type_id: InsurableType::RESIDENTIAL_UNITS_IDS)
                                   .where.not(id: Reporting::UnitCoverageEntry.where(report_time: self.coverage_report.report_time).select(:insurable_id))
                                   .where.not(account_id: nil)
                                   .send(*self.ownership_constraint)
                                   .where(id: ::IntegrationProfile.where(integration: self.reportable.integration, external_context: "unit_in_community_#{self.reportable.external_id}").select(:profileable_id))
                                   .pluck(:id)
              )
              # generate links
              Reporting::CoverageEntryLink.try_insert_all(Reporting::UnitCoverageEntry.where(
                report_time: self.coverage_report.report_time,
                insurable_id: IntegrationProfile.where(integration: self.reportable.integration, external_context: "unit_in_community_#{self.reportable.external_id}").select(:profileable_id)
              ).pluck(:id).map{|uce_id| { parent_id: self.id, child_id: uce_id, direct: true } })
              # accumulate
              self.accumulate_units
            else
              raise StandardError.new("Only community integration profiles are supported!")
            end
          elsif self.reportable_type == 'InsurableGeographicalCategory'
            # states WARNING: assumes community entries are already generated
            if self.parent.reportable_category == "PM Account"
              accumulate_children(parent_override: self.parent, category: "Community", filter: Proc.new{|ce| ce.reportable&.primary_address&.state == self.reportable.state })
            else
              raise StandardError.new("")
            end
          elsif self.reportable_type == 'Account'
            # pm accounts
            # generate community entries
            ids = Insurable.confirmed.where(account_id: self.reportable_id, insurable_type_id: InsurableType::RESIDENTIAL_COMMUNITIES_IDS)
                                     .send(*self.ownership_constraint)
                                     .pluck(:id)
            ids.each do |id|
              found = Insurable.find(id)
              created = begin
                Reporting::CoverageEntry.create!(parent: self, reportable_category: "Community", coverage_report: self.coverage_report, reportable: found)
              rescue ActiveRecord::RecordInvalid => e
                raise unless (e.record.errors.to_hash.all?{|k,v| v == "has already been taken" } rescue false)
                nil # we just ignore this error, we're apparently in what would with locks be a race condition and someone else created it first, but so what?
              end
              created&.generate!
            end
            ids.clear
            # generate yardi property entries
            ids = IntegrationProfile.where(integration_id: self.reportable.integrations.where(provider: 'yardi').pluck(:id), external_context: "community").pluck(:id)
            ids.each do |id|
              found = IntegrationProfile.find(id)
              next if found.profileable.nil?
              created = begin
                Reporting::CoverageEntry.create!(parent: self, reportable_category: "Yardi Property", coverage_report: self.coverage_report, reportable: found)
              rescue ActiveRecord::RecordInvalid => e
                raise unless (e.record.errors.to_hash.all?{|k,v| v == "has already been taken" } rescue false)
                nil # we just ignore this error, we're apparently in what would with locks be a race condition and someone else created it first, but so what?
              end
              created&.generate!
            end
            ids.clear
            # generate state entries
            Address.where(
              primary: true,
              addressable_type: "Insurable",
              addressable_id: Insurable.confirmed.where(account_id: self.reportable_id, insurable_type_id: InsurableType::RESIDENTIAL_COMMUNITIES_IDS)
                                       .send(*self.ownership_constraint)
                                       .pluck(:id)
            ).pluck(:state).uniq.each do |state|
              found = ::InsurableGeographicalCategory.get_for(state: state)
              created = begin
                Reporting::CoverageEntry.create!(parent: self, reportable_category: "State", coverage_report: self.coverage_report, reportable: found)
              rescue ActiveRecord::RecordInvalid => e
                raise unless (e.record.errors.to_hash.all?{|k,v| v == "has already been taken" } rescue false)
                nil # we just ignore this error, we're apparently in what would with locks be a race condition and someone else created it first, but so what?
              end
              created&.generate!
            end
            # accumulate
            self.accumulate_children(category: "Community")
          elsif self.reportable_type.nil?
            # generate account entries
            ids = ::Account.where(reporting_coverage_reports_generate: true).pluck(:id)
            ids.each do |id|
              found = ::Account.find(id)
              next if found.nil?
              created = begin
                Reporting::CoverageEntry.create!(parent: self, reportable_category: "PM Account", coverage_report: self.coverage_report, reportable: found)
              rescue ActiveRecord::RecordInvalid => e
                raise unless (e.record.errors.to_hash.all?{|k,v| v == "has already been taken" } rescue false)
                nil # we just ignore this error, we're apparently in what would with locks be a race condition and someone else created it first, but so what?
              end
              created&.generate!
            end
            # universe
            self.accumulate_children(category: "PM Account")
          end
          # donesies
          self.status = 'generated'
          self.save!
        end # end transaction
      rescue StandardError => e
        self.reload.update(status: 'errored', error_data: { error_class: e.class.name, error_message: e.message, error_backtrace: e.backtrace })
        raise if bang
        to_return = e
      rescue
        self.reload.update(status: 'errored', error_data: { error_class: "Unknown" })
        raise if bang
        to_return = "Unknown Error"
      end # end begin/rescue
      return to_return
    end
    
    # use some_insurable_query.send(*ownership_constraint) to filter for appropriately owned insurables
    def ownership_constraint
      if @coverage_report_owner != [self.coverage_report.owner_type, self.coverage_report.owner_id]
        @ownership_constraint = nil
        @coverage_report_owner = [self.coverage_report.owner_type, self.coverage_report.owner_id]
      end
      @ownership_constraint ||= case self.coverage_report.owner_type
        when 'Account'
          [:where, { account_id: self.coverage_report.owner_id }]
        when 'Agency'
          [:where, { account_id: Account.where(agency_id: [self.coverage_report.owner_id] + self.coverage_report.owner.agencies.pluck(:id)).select(:id) }]
        when nil
          [:itself]
        else
          [:where, { id: 0 }]
      end
    end
    
    # generate UnitCoverageEntry objects for each insurable id passed
    def generate_unit_entries(ids)
      ids.each do |id|
        begin
          created = Reporting::UnitCoverageEntry.create!(report_time: self.coverage_report.report_time, insurable: Insurable.find(id))
          created.generate!
        rescue ActiveRecord::RecordInvalid => e
          raise unless (e.record.class == Reporting::UnitCoverageEntry && e.record.errors.to_hash.all?{|k,v| v == "has already been taken" } rescue false)
          Reporting::UnitCoverageEntry.where(report_time: self.coverage_report.report_time, insurable: Insurable.find(id)).take&.generate!
          nil # we just ignore this error, we're apparently in what would with locks be a race condition and someone else created it first, but so what?
        end
      end
    end
    
    # accumulate values from child CoverageEntry objects
    def accumulate_children(category: nil, parent_override: self, filter: nil)
      parent_override.children.send(*(category.nil? ? [:itself] : [:where, { reportable_category: category }])).reload.each do |child|
        next unless filter.nil? || filter.call(child)
        self.total_units += child.total_units
        self.total_units_unoccupied += child.total_units_unoccupied
        self.total_units_with_master_policy += child.total_units_with_master_policy
        self.total_units_with_internal_policy += child.total_units_with_internal_policy
        self.total_units_with_external_policy += child.total_units_with_external_policy
        self.total_units_with_no_policy += child.total_units_with_no_policy
      end
    end
    
    # accumulate values from linked UnitCoverageEntry objects
    def accumulate_units(direct: nil)
      unit_entries = self.unit_coverage_entries.references(:reporting_coverage_entry_links).includes(:links).send(*(direct.nil? ? [:itself] : [:where, { reporting_coverage_entry_links: { direct: direct } }]))
      self.total_units += unit_entries.count
      unit_entries.each do |ue|
        self.total_units_unoccupied += 1 if !ue.occupied
        case(self.coverage_report.coverage_determinant == 'mixed' ? ue.coverage_status : ue.send("coverage_status_#{self.coverage_report.coverage_determinant}"))
          when 'none'
            self.total_units_with_no_policy += 1
          when 'internal'
            self.total_units_with_internal_policy += 1
          when 'external'
            self.total_units_with_external_policy += 1
          when 'internal_and_external' # count as internal
            self.total_units_with_internal_policy += 1
          when 'internal_or_external' # count as internal
            self.total_units_with_internal_policy += 1
          when 'master'
            self.total_units_with_master_policy += 1
        end
      end
    end
    
    # set statistics that can easily be derived from others
    def set_derived_statistics
      tud = self.total_units == 0 ? 1 : self.total_units.to_d
      self.percent_units_unoccupied = 100 * self.total_units_unoccupied.to_d / tud
      self.total_units_with_ho4_policy = self.total_units_with_internal_policy + self.total_units_with_external_policy
      ['master_policy', 'internal_policy', 'external_policy', 'ho4_policy', 'no_policy'].each do |prop|
        self.send("percent_units_with_#{prop}=", 100 * self.send("total_units_with_#{prop}").to_d / tud)
      end
    end


  end # end class
end
