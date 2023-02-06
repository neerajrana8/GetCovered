
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
      
    has_many :unit_coverage_entries,
      class_name: "Reporting::UnitCoverageEntry",
      through: :coverage_entries,
      source: :unit_coverage_entries
    
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
      reports = Reporting::CoverageReport.where(report_time: report_time, owner_type: [nil, "Account"]).pluck(:owner_id, :coverage_determinant, :status, :id)
      # generate root reports
      puts "[Reporting::CoverageReport.generate_all!] Generating #{Reporting::CoverageReport.coverage_determinants.count} root reports..."
      Reporting::CoverageReport.coverage_determinants.keys.each.with_index do |cd, ind|
        found = reports.find{|r| r[0].nil? && r[1] == cd }
        case found&.[](2)
          when 'ready'
            # do nothing
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1} / #{Reporting::CoverageReport.coverage_determinants.count}) Root '#{cd}' report already generated."
          when 'preparing', 'errored'
            # try to regenerate
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1} / #{Reporting::CoverageReport.coverage_determinants.count}) Root '#{cd}' report exists but has not been fully generated; attempting generation."
            Reporting::CoverageReport.find(found[3]).generate!
          when nil
            # try to create
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1} / #{Reporting::CoverageReport.coverage_determinants.count}) Generating root '#{cd}' report."
            Reporting::CoverageReport.create!(owner: nil, report_time: report_time, coverage_determinant: cd).generate!
        end
      end
      # generate account reports
      account_ids = ::Account.where(reporting_coverage_reports_generate: true).order(id: :asc).pluck(:id)
      puts "[Reporting::CoverageReport.generate_all!] Generating #{account_id.count} PM account reports..."
      account_ids.each.with_index do |account_id, ind|
        account = Account.find(account_id)
        cd = (account.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any'
        found = reports.find{|r| r[0] == account_id && r[1] == cd }
        case found&.[](2)
          when 'ready'
            # do nothing
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1}/#{account_id.count}) Report for PM '#{account.title}' already generated."
          when 'preparing', 'errored'
            # try to regenerate
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1}/#{account_id.count}) Report for PM '#{account.title}' exists but has not been fully generated; attempting generation."
            Reporting::CoverageReport.find(found[3]).generate!
          when nil
            # try to create
            puts "[Reporting::CoverageReport.generate_all!]   (#{ind+1}/#{account_id.count}) Generating report for PM '#{account.title}'."
            Reporting::CoverageReport.create!(owner: account, report_time: report_time, coverage_determinant: cd).generate!
        end
      end
      puts "[Reporting::CoverageReport.generate_all!] Report generation complete."
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
    
    def manifest
      # determine what aspects of the manifest to make visible
      show_yardi = self.owner_type == "Account" && !self.owner.integrations.where(provider: 'yardi').blank? ? true : false
      show_insurables = !show_yardi
      show_universe = false
      hide_internal_vs_external = true
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
        { title: "# Master Policy Units", sortable: true, apiIndex: "total_units_with_master_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "# HO4 Policy Units", sortable: true, apiIndex: "total_units_with_ho4_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "# GC Policy Units", sortable: true, apiIndex: "total_units_with_internal_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "# Uploaded Policy Units", sortable: true, apiIndex: "total_units_with_external_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "# No Policy Units", sortable: true, apiIndex: "total_units_with_no_policy", data_type: "integer", filters: ['scalar', 'interval'] },
        { title: "% Master Policy Units", sortable: true, apiIndex: "percent_units_with_master_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        { title: "% HO4 Policy Units", sortable: true, apiIndex: "percent_units_with_ho4_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "% GC Policy Units", sortable: true, apiIndex: "percent_units_with_internal_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        hide_internal_vs_external ? nil : { title: "% Uploaded Policy Units", sortable: true, apiIndex: "percent_units_with_external_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] },
        { title: "% No Policy Units", sortable: true, apiIndex: "percent_units_with_no_policy", data_type: "number", format: "percent", filters: ['scalar', 'interval'] }
      ].compact
      dat_manifest = {
        title: "Coverage",
        root_subreport: show_universe ? "Universe" : "PM Accounts",
        subreports: [
          !show_insurables ? nil : {
            title: "Units",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/unit-entries",
            fixed_filters: {},
            unique: ["id"],
            columns: [
              { title: "Address", sortable: true, apiIndex: "street_address", filters: ['scalar', 'vector', 'like'] },
              { title: "Unit", sortable: true, apiIndex: "unit_number", filters: ['scalar', 'vector', 'like'] },
              { title: "Coverage", sortable: true, apiIndex: "coverage_status", data_type: "enum",
                enum_values: visible_enum_values,
                format: visible_enum_values.map{|vev| vev.titlecase },
                filters: ['scalar', 'vector']
              },
              { title: "# Lessees", sortable: true, apiIndex: "lessee_count", data_type: "integer", filters: ['scalar', 'vector', 'interval'] }
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
              { title: "Address", sortable: true, apiIndex: "street_address", filters: ['scalar', 'vector', 'like'] },
              { title: "Community", sortable: true, apiIndex: "reportable_title", filters: ['scalar', 'vector', 'like'] }
            ].compact + standard_columns
          },
          !show_yardi ? nil : {
            title: "Yardi Units",
            endpoint: "/v2/reporting/coverage-reports/#{self.id}/unit-entries",
            fixed_filters: {},
            unique: ["id"],
            columns: [
              { title: "Address", sortable: true, apiIndex: "street_address", filters: ['scalar', 'like'] },
              { title: "Unit", sortable: true, apiIndex: "yardi_id", filters: ['scalar', 'vector', 'like'] },
              { title: "Coverage", sortable: true, apiIndex: "coverage_status", data_type: "enum",
                enum_values: visible_enum_values,
                format: visible_enum_values.map{|vev| vev.titlecase },
                filters: ['scalar', 'vector']
              },
              { title: "# Lessees", sortable: true, apiIndex: "lessee_count", data_type: "integer", filters: ['scalar', 'interval'] }
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
        subreport_links: [
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
        ]
      }
      dat_manifest[:subreport_links].select!{|link| dat_manifest[:subreports].any?{|sr| sr[:title] == link[:origin] } && dat_manifest[:subreports].any?{|sr| sr[:title] == link[:destination] } }
      return(dat_manifest)
    end



    private

      def set_coverage_determinant
        self.coverage_determinant ||= (self.owner.reporting_coverage_reports_settings || {})['coverage_determinant'] || 'any' if self.owner_type == "Account"
      end
        
  end # end class
end
