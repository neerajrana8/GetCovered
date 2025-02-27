
=begin
      EXAMPLE MANIFEST FORMAT:
      {
        title: string,
        subreports: [{ # array instead of hash to preserve order when send to javascript frontend
         title: string (unique),
         endpoint: string,
         fixed_filters: hash,
         columns: [
           {
             title: string,
             sortable: boolean,
             apiIndex: integer or string (controller returns array of fellas, each fella is an array or a hash, this is the integer or string key to get this column out of each fella),
             format: [boolean, percent, number, dollars, cents, string],
             [invisible: true/false (default false; use true to provide frontend with properties for filtering etc that don't actually need to be displayed)]
           }
         ],
         [sort]: optional default sort hash,
         [filter]: optional default filter hash,
         [pagination]: optional default pagination hash
        }],
        subreport_links: [{
          title: string,
          origin: subreport title,
          destination: subreport title,
          fixed_filters: {
            <subreport column title>: string (can use ${prop} where prop is a subreport column title from origin)
          },
          copied_columns: [<subreport column title from origin>]
        }]
      }
=end

module Reporting
  class CoverageReport < ApplicationRecord
    self.table_name = "reporting_coverage_reports"
    include Reporting::CoverageDetermining # provides COVERAGE_DETERMINANTS enum setup
    
    belongs_to :owner,
      polymorphic: true,
      optional: true
    
    has_many :coverage_entries,
      class_name: "Reporting::CoverageEntry",
      inverse_of: :coverage_report,
      foreign_key: :coverage_report_id

    def unit_coverage_entries
      if owner.nil?
        Reporting::UnitCoverageEntry.where(report_time: self.report_time)
      elsif owner.class == ::Account
        Reporting::UnitCoverageEntry.where(
          report_time: self.report_time,
          account_id: owner.id
        )
      else
        Reporting::UnitCoverageEntry.where(
          report_time: self.report_time,
          account_id: owner.accounts.select(:id)
        )
      end
    end
    
    def lease_coverage_entries
      if owner.nil?
        Reporting::LeaseCoverageEntry.where(report_time: self.report_time)
      elsif owner.class == ::Account
        Reporting::LeaseCoverageEntry.where(
          report_time: self.report_time,
          account_id: owner.id
        )
      else
        Reporting::LeaseCoverageEntry.where(
          report_time: self.report_time,
          account_id: owner.accounts.select(:id)
        )
      end
    end
    
    def lease_user_coverage_entries
      if owner.nil?
        Reporting::LeaseUserCoverageEntry.where(report_time: self.report_time)
      elsif owner.class == ::Account
        Reporting::LeaseUserCoverageEntry.where(
          report_time: self.report_time,
          account_id: owner.id
        )
      else
        Reporting::LeaseUserCoverageEntry.where(
          report_time: self.report_time,
          account_id: owner.accounts.select(:id)
        )
      end
    end

    # using methods instead because otherwise we get duplicate unit entries and have a lot of unneeded joins...
    # left this here in case someone comes up with a nice way to customize the assocs instead
=begin
    has_many :unit_coverage_entries,
      class_name: "Reporting::UnitCoverageEntry",
      through: :coverage_entries,
      source: :unit_coverage_entries
      
    has_many :lease_coverage_entries,
      class_name: "Reporting::LeaseCoverageEntry",
      through: :unit_coverage_entries,
      source: :lease_coverage_entries

    has_many :lease_user_coverage_entries,
      class_name: "Reporting::LeaseUserCoverageEntry",
      through: :lease_coverage_entries,
      source: :lease_user_coverage_entries
=end
    
    before_create :set_coverage_determinant
    
    before_destroy :destroy_children
    
    enum status: {
      preparing: 0,
      ready: 1,
      errored: 2
    }

    enum coverage_determinant: COVERAGE_DETERMINANTS,
      _prefix: false, _suffix: false
    
    def self.generate_all!(report_time)
      failed_creations = []
      failed_generations = []
      reports = Reporting::CoverageReport.where(report_time: report_time, owner_type: [nil, "Account"]).pluck(:owner_id, :coverage_determinant, :status, :id)
      # generate PM reports
      account_ids = ::Account.where(reporting_coverage_reports_generate: true).order(id: :asc).pluck(:id)
      puts "[Reporting::CoverageReport.generate_all!] Generating #{account_ids.count} PM account reports..."
      account_ids.each.with_index do |account_id, ind|
        account = Account.find(account_id)
        cd = (account.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any'
        found = reports.find{|r| r[0] == account_id && r[1] == cd }
        case found&.[](2)
          when 'ready'
            # do nothing
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1}/#{account_ids.count}) Report for PM '#{account.title}' already generated (id: #{found[3]})."
          when 'preparing', 'errored'
            # try to regenerate
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1}/#{account_ids.count}) Report for PM '#{account.title}' exists but has not been fully generated (id: #{found[3]}); attempting regeneration."
            report = Reporting::CoverageReport.find(found[3])
            result = report.generate!
            if result.nil?
              puts "[Reporting::CoverageReport.generate_all!]     Report generated successfully."
            else
              puts "[Reporting::CoverageReport.generate_all!]     Report generation failed: #{result[:class]}: #{result[:message]}"
              failed_generations.push(report.id)
            end
          when nil
            # try to create
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1}/#{account_ids.count}) Generating new report for PM '#{account.title}'."
            report = Reporting::CoverageReport.create!(owner: account, report_time: report_time, coverage_determinant: cd)
            if report.id
              puts "[Reporting::CoverageReport.generate_all!]     Report created (id #{report.id}); beginning generation."
              result = report.generate!
              if result.nil?
                puts "[Reporting::CoverageReport.generate_all!]     Report generated successfully."
              else
                puts "[Reporting::CoverageReport.generate_all!]     Report generation failed: #{result[:class]}: #{result[:message]}"
                failed_generations.push(report.id)
              end
            else
              puts "[Reporting::CoverageReport.generate_all!]     Failed to create report: #{report.errors.to_h}"
              failed_creations.push(account_id)
            end
        end
      end
      # generate root report
      puts "[Reporting::CoverageReport.generate_all!] Generating root report..."
      found = reports.find{|r| r[0].nil? && r[1] == 'mixed' }
      case found&.[](2)
        when 'ready'
          puts "[Reporting::CoverageReport.generate_all!]   Root report already generated (id: #{found[3]})."
        when 'preparing', 'errored'
          puts "[Reporting::CoverageReport.generate_all!]   Root report exists but has not been fully generated (id: #{found[3]}); attempting regeneration."
          report = Reporting::CoverageReport.find(found[3])
          result = report.generate!
          if result.nil?
            puts "[Reporting::CoverageReport.generate_all!]     Report generated successfully."
          else
            puts "[Reporting::CoverageReport.generate_all!]     Report generation failed: #{result[:class]}: #{result[:message]}"
            failed_generations.push(report.id)
          end
        when nil
          puts "[Reporting::CoverageReport.generate_all!]   Generating new root report."
          report = Reporting::CoverageReport.create!(owner: nil, report_time: report_time, coverage_determinant: 'mixed')
          if report.id
            puts "[Reporting::CoverageReport.generate_all!]     Report created (id #{report.id}); beginning generation."
            result = report.generate!
            if result.nil?
              puts "[Reporting::CoverageReport.generate_all!]     Report generated successfully."
            else
              puts "[Reporting::CoverageReport.generate_all!]     Report generation failed: #{result[:class]}: #{result[:message]}"
              failed_generations.push(report.id)
            end
          else
            puts "[Reporting::CoverageReport.generate_all!]     Failed to create report: #{report.errors.to_h}"
            failed_creations.push(nil)
          end
      end
      puts "[Reporting::CoverageReport.generate_all!] Report generation complete."
      puts "[Reporting::CoverageReport.generate_all!]   Account ids for which report creation failed: #{failed_creations}"
      puts "[Reporting::CoverageReport.generate_all!]   Report ids for which report generation failed: #{failed_generations}"
      puts "[Reporting::CoverageReport.generate_all!] Have a nice day."
      return true
    end
    
    def generate!
      self.generate(bang: true)
    end
    
    def generate(bang: false)
      return { class: "AlreadyRunError", message: "CoverageReport ##{self.id} has already been generated!" } if status == 'ready'
      to_return = nil
      begin
        self.update!(status: 'preparing', report_time: self.report_time || Time.current)
        ActiveRecord::Base.transaction(requires_new: false) do
          created = if self.owner_id.nil?
            Reporting::CoverageEntry.create!(reportable_category: "Universe", coverage_report: self, reportable: nil, parent_id: nil)
          elsif self.owner_type == "Account"
            Reporting::CoverageEntry.create!(reportable_category: "PM Account", coverage_report: self, reportable_type: "Account", reportable_id: self.owner_id, parent_id: nil)
          else
            raise StandardError.new("Owner must be an Account or the EMPEROR (i.e. nil)!")
          end
          created.generate!
          self.update!(status: 'ready', completed_at: Time.current)
        end # end transaction
      rescue StandardError => e
        self.update!(status: 'errored', error_data: (self.error_data || {}).merge({
          self.report_time.to_s => (to_return = {
            class: e.class.name,
            message: (e.message rescue nil),
            backtrace: (e.backtrace rescue nil)
          })
        }))
        raise if bang
      end # end try-catch
      return to_return
    end
    
    def expand_ho4?
      self.owner_type.nil? # only expand for superadmin right now
    end
    
    def destroy_children
      Reporting::CoverageEntryLink.where(parent: self.coverage_entries).delete_all
      self.coverage_entries.delete_all
    end
    
    def manifest(with_root = nil)
      # determine what aspects of the manifest to make visible
      show_yardi = self.owner_type == "Account" && !self.owner.integrations.where(provider: 'yardi').blank? ? true : false
      show_insurables = !show_yardi
      show_universe = false
      hide_internal_vs_external = false
      if self.owner_type.nil? # superadmin view
        show_insurables = true
        show_yardi = true
        show_universe = true
        hide_internal_vs_external = false
      end
      visible_enum_values = !self.expand_ho4? ? ['none', 'master', 'ho4'] : self.owner_type.nil? ? ['none', 'master', 'external', 'internal', 'internal_and_external', 'internal_or_external'] : ['none', 'master', 'external', 'internal']
      # build the manifest
      standard_columns = [ # we reuse these a lot so centralizing them here
        { title: "id", apiIndex: "id", invisible: true },
        { title: "# Units", sortable: true, apiIndex: "total_units", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "# Master Policy", sortable: true, apiIndex: "total_units_with_master_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "# HO4 Policy", sortable: true, apiIndex: "total_units_with_ho4_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "# GC Policy", sortable: true, apiIndex: "total_units_with_internal_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "# Uploaded Policy", sortable: true, apiIndex: "total_units_with_external_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "# No Policy", sortable: true, apiIndex: "total_units_with_no_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "# Unoccupied", sortable: true, apiIndex: "total_units_unoccupied", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "% Master Policy", sortable: true, apiIndex: "percent_units_with_master_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        { title: "% HO4 Policy", sortable: true, apiIndex: "percent_units_with_ho4_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "% GC Policy", sortable: true, apiIndex: "percent_units_with_internal_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "% Uploaded Policy", sortable: true, apiIndex: "percent_units_with_external_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        { title: "% No Policy", sortable: true, apiIndex: "percent_units_with_no_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        { title: "% Unoccupied", sortable: true, apiIndex: "percent_units_unoccupied", data_type: "number", format: "percent", filters: ['scalar', 'interval'] }
      ].compact
      dat_manifest = {
        title: "Coverage",
        root_subreport: show_universe ? "Universe" : "PM Accounts",
        subreports: [
          {
            title: "Residents",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/lease-user-entries",
            fixed_filters: {},
            unique: ["id"],
            columns: [
              { title: "id", apiIndex: "id", invisible: true },
              show_yardi ? { title: "Yardi Code", sortable: true, apiIndex: "yardi_id", filters: ['scalar', 'array', 'like'] } : nil,
              { title: "Email", sortable: true, apiIndex: "email", filters: ['scalar', 'array', 'like'] },
              { title: "First Name", sortable: true, apiIndex: "first_name", filters: ['scalar', 'array', 'like'] },
              { title: "Last Name", sortable: true, apiIndex: "last_name", filters: ['scalar', 'array', 'like'] },
              { title: "Lessee", sortable: true, apiIndex: "lessee", filters: ['scalar'], data_type: 'boolean' },
              { title: "Current", sortable: true, apiIndex: "current", filters: ['scalar'], data_type: 'boolean' },
              { title: "Coverage", sortable: true, apiIndex: "coverage_status", data_type: "enum",
                enum_values: visible_enum_values,
                format: visible_enum_values.map{|vev| vev.titlecase },
                filters: ['scalar', 'array']
              },
              { title: "Policy", sortable: true, apiIndex: "policy_number" }
            ].compact
          },
          {
            title: "Leases",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/lease-entries",
            fixed_filters: {},
            unique: ["id"],
            columns: [
              { title: "id", apiIndex: "id", invisible: true },
              { title: "unit_coverage_entry_id", apiIndex: "unit_coverage_entry_id", invisible: true },
              { title: "lease_id", apiIndex: "lease_id", invisible: true },
              show_yardi ? { title: "Yardi ID", sortable: true, apiIndex: "yardi_id", filters: ['scalar', 'array', 'like'] } : nil,
              { title: "Status", sortable: true, apiIndex: "status", data_type: "enum",
                enum_values: ::Lease.statuses.keys,
                format: ::Lease.statuses.keys.map{|s| s.titlecase },
                filters: ['scalar', 'array']
              },
              { title: "Start", sortable: true, apiIndex: "start_date", data_type: "date" },
              { title: "End", sortable: true, apiIndex: "end_date", data_type: "date" },
              { title: "# Lessees", sortable: true, apiIndex: "lessee_count", data_type: "integer", filters: ['scalar', 'array', 'interval'] },
              { title: "Coverage", sortable: true, apiIndex: "coverage_status", data_type: "enum",
                enum_values: visible_enum_values,
                format: visible_enum_values.map{|vev| vev.titlecase },
                filters: ['scalar', 'array']
              }
            ]
          },
          !show_insurables ? nil : {
            title: "Units",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/unit-entries",
            fixed_filters: {},
            unique: ["id"],
            columns: [
              { title: "id", apiIndex: "id", invisible: true },
              { title: "primary_lease_coverage_entry_id", apiIndex: "primary_lease_coverage_entry_id", invisible: true },
              { title: "Address", sortable: true, apiIndex: "street_address", filters: ['scalar', 'array', 'like'] },
              { title: "Unit", sortable: true, apiIndex: "unit_number", filters: ['scalar', 'array', 'like'] },
              { title: "Coverage", sortable: true, apiIndex: "coverage_status", data_type: "enum",
                enum_values: visible_enum_values,
                format: visible_enum_values.map{|vev| vev.titlecase },
                filters: ['scalar', 'array']
              },
              { title: "Occupied", sortable: true, apiIndex: "occupied", data_type: "boolean", filters: ['scalar'] }
            ].compact
          },
          !show_insurables ? nil : {
            title: "Communities",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/entries",
            fixed_filters: {
              reportable_category: "Community"
            },
            unique: ["id"],
            columns: [
              { title: "Address", sortable: true, apiIndex: "reportable_description", filters: ['scalar', 'array', 'like'] },
              { title: "Community", sortable: true, apiIndex: "reportable_title", filters: ['scalar', 'array', 'like'] }
            ].compact + standard_columns
          },
          !show_yardi ? nil : {
            title: "Yardi Units",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/unit-entries",
            fixed_filters: {},
            unique: ["id"],
            columns: [
              { title: "id", apiIndex: "id", invisible: true },
              { title: "primary_lease_coverage_entry_id", apiIndex: "primary_lease_coverage_entry_id", invisible: true },
              { title: "Address", sortable: true, apiIndex: "street_address", filters: ['scalar', 'like'] },
              { title: "Unit", sortable: true, apiIndex: "yardi_id", filters: ['scalar', 'array', 'like'] },
              { title: "Yardi Lease", sortable: true, apiIndex: "lease_yardi_id", filters: ['scalar', 'array', 'like'] },
              { title: "Coverage", sortable: true, apiIndex: "coverage_status", data_type: "enum",
                enum_values: visible_enum_values,
                format: visible_enum_values.map{|vev| vev.titlecase },
                filters: ['scalar', 'array']
              },
              { title: "Occupied", sortable: true, apiIndex: "occupied", data_type: "boolean", filters: ['scalar'] }
            ].compact
          },
          !show_yardi ? nil : {
            title: "Yardi Properties",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/entries",
            fixed_filters: {
              reportable_category: "Yardi Property"
            },
            unique: ["id"],
            columns: [
              { title: "Title", sortable: true, apiIndex: "reportable_description", filters: ['scalar', 'like'] },
              { title: "Property Code", sortable: true, apiIndex: "reportable_title", filters: ['scalar', 'like'] }
            ].compact + standard_columns
          },
          {
            title: "States",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/entries",
            fixed_filters: {
              reportable_category: "State"
            },
            unique: ["id"],
            columns: [
              { title: "State", sortable: true, apiIndex: "reportable_title", filters: ['scalar','like'] }
            ].compact + standard_columns
          },
          {
            title: "PM Accounts",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/entries",
            fixed_filters: {
              reportable_category: "PM Account"
            },
            unique: ["id"],
            columns: [
              { title: "PM Account", sortable: true, apiIndex: "reportable_title", filters: ['scalar','like'] }
            ].compact + standard_columns,
            direct_access: show_universe ? false : true
          },
          !show_universe ? nil : {
            title: "Universe",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/entries",
            fixed_filters: {
              reportable_category: "Universe"
            },
            unique: ["id"],
            columns: standard_columns,
            direct_access: true
          }
        ].compact,
        subreport_links: (['Units', 'Yardi Units'].map do |orig|
          [
            {
              title: "Residents",
              origin: orig,
              destination: "Residents",
              fixed_filters: {
                lease_coverage_entry_id: "primary_lease_coverage_entry_id"
              },
              copied_columns: [
                "Address",
                "Unit"
              ]
            },
            {
              title: "Leases",
              origin: orig,
              destination: "Leases",
              fixed_filters: {
                unit_coverage_entry_id: "id"
              },
              copied_columns: [
                "Address",
                "Unit"
              ]
            }
          ]
        end.flatten + [
          {
            title: "Residents",
            origin: "Leases",
            destination: "Residents",
            fixed_filters: {
              lease_coverage_entry_id: "id"
            },
            copied_columns: [
              "Address",
              "Unit"
            ]
          },
          {
            title: "Units",
            origin: "Communities",
            destination: "Units",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: [
              "Community"
            ]
          },
          {
            title: "Buildings",
            origin: "Communities",
            destination: "Buildings",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: [
              "Community"
            ]
          },
          {
            title: "Units",
            origin: "Yardi Properties",
            destination: "Yardi Units",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: [
              "Property Code"
            ]
          },
          {
            title: "Communities",
            origin: "PM Accounts",
            destination: "Communities",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: self.owner_type == "Account" ? [] : ["PM Account"]
          },
          {
            title: "Yardi Properties",
            origin: "PM Accounts",
            destination: "Yardi Properties",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: self.owner_type == "Account" ? [] : ["PM Account"]
          },
          {
            title: "States",
            origin: "PM Accounts",
            destination: "States",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: self.owner_type == "Account" ? [] : ["PM Account"]
          },
          {
            title: "PM Accounts",
            origin: "Universe",
            destination: "PM Accounts",
            fixed_filters: {
              parent_id: "id"
            },
            copied_columns: []
          }
        ])
      }
      # filter out links to/from any pages we didn't make available
      dat_manifest[:subreport_links].select!{|link| dat_manifest[:subreports].any?{|sr| sr[:title] == link[:origin] } && dat_manifest[:subreports].any?{|sr| sr[:title] == link[:destination] } }
      return(dat_manifest)
    end



    private

      def set_coverage_determinant
        if self.owner_type == "Account"
          self.coverage_determinant ||= (self.owner.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any'
        elsif self.owner_type.nil?
          self.coverage_determinant ||= 'mixed'
        end
      end
        
  end # end class
end
