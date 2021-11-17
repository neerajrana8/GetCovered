module Reports
  class DailySalesAggregate < ::Report
    NAME = 'Daily Sales Aggregate Report'.freeze

    def generate
      if reportable.nil?
        aggregate_report
      elsif reportable.is_a?(Agency)
        report = agency_report
        flatten_agency_report(report)
      elsif reportable.is_a?(Account)
        data['rows'] << item_report(reportable)
      end

      calculate_total_conversion_percentages
      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << [
          'Partner', 'Type', 'Parent Agency', 'Status',
          '', '', '', '', '', '', '', '', '', '',
          'Prior 7 Days', '', '', '', '', '', '', '', '', '',
          'Prior 30 Days', '', '', '', '', '', '', '', '', ''
        ]

        csv << [
          '', '', '', '',
          range_start_edt.yesterday.to_date, '', '', '', '', '', '', '', '', '',
          "(#{(range_start - 7.days).to_date}  - #{range_start_edt.yesterday.to_date})", '', '', '', '', '', '', '', '', '',
          "(#{(range_start - 30.days).to_date} - #{range_start_edt.yesterday.to_date})", '', '', '', '', '', '', '', '', ''
        ]
        csv << [
          '', '', '', '',
          'Site Visits', 'Total Visitors', 'Apps Started', 'Subm', 'Leads', 'Conv', 'Conv %', 'Total Premiums', 'Partner Comm\'n', 'GC Comm\'n',
          'Site Visits', 'Total Visitors', 'Apps Started', 'Subm', 'Leads', 'Conv', 'Conv %', 'Total Premiums', 'Partner Comm\'n', 'GC Comm\'n',
          'Site Visits', 'Total Visitors', 'Apps Started', 'Subm', 'Leads', 'Conv', 'Conv %', 'Total Premiums', 'Partner Comm\'n', 'GC Comm\'n'
        ]

        unless reportable.is_a?(Account)
          csv << [
            'TOTAL', '', '', '',
            *data['totals']['yesterday'].values_at(*daily_sales_columns[:without_formatting]),
            *data['totals']['yesterday'].values_at(*daily_sales_columns[:percent]).map { |value| value.zero? ? 0 : "#{value}%" },
            *data['totals']['yesterday'].values_at(*daily_sales_columns[:money]).map { |value| "$#{(value / 100.0).to_s(:delimited)}" },
            *data['totals']['prior_seven_days'].values_at(*daily_sales_columns[:without_formatting]),
            *data['totals']['prior_seven_days'].values_at(*daily_sales_columns[:percent]).map { |value| value.zero? ? 0 : "#{value}%" },
            *data['totals']['prior_seven_days'].values_at(*daily_sales_columns[:money]).map { |value| "$#{(value / 100.0).to_s(:delimited)}" },
            *data['totals']['prior_thirty_days'].values_at(*daily_sales_columns[:without_formatting]),
            *data['totals']['prior_thirty_days'].values_at(*daily_sales_columns[:percent]).map { |value| value.zero? ? 0 : "#{value}%" },
            *data['totals']['prior_thirty_days'].values_at(*daily_sales_columns[:money]).map { |value| "$#{(value / 100.0).to_s(:delimited)}" }
          ]
        end

        data['rows'].each do |row|
          csv << [
            *row.values_at('title', 'type', 'parent_agency', 'status'),
            *row['data']['yesterday'].values_at(*daily_sales_columns[:without_formatting]),
            *row['data']['yesterday'].values_at(*daily_sales_columns[:percent]).map { |value| value.zero? ? 0 : "#{value}%" },
            *row['data']['yesterday'].values_at(*daily_sales_columns[:money]).map { |value| "$#{(value / 100.0).to_s(:delimited)}" },
            *row['data']['prior_seven_days'].values_at(*daily_sales_columns[:without_formatting]),
            *row['data']['prior_seven_days'].values_at(*daily_sales_columns[:percent]).map { |value| value.zero? ? 0 : "#{value}%" },
            *row['data']['prior_seven_days'].values_at(*daily_sales_columns[:money]).map { |value| "$#{(value / 100.0).to_s(:delimited)}" },
            *row['data']['prior_thirty_days'].values_at(*daily_sales_columns[:without_formatting]),
            *row['data']['prior_thirty_days'].values_at(*daily_sales_columns[:percent]).map { |value| value.zero? ? 0 : "#{value}%" },
            *row['data']['prior_thirty_days'].values_at(*daily_sales_columns[:money]).map { |value| "$#{(value / 100.0).to_s(:delimited)}" }
          ]
        end
      end
    end

    def generate_csv
      document_title =
        "#{reportable&.title || 'All partners'}-Daily-Report-#{range_start_edt.strftime('%B %-d %Y')}.csv".downcase.tr(' ', '-')

      save_path = Rails.root.join('tmp', document_title)

      File.open(save_path, 'wb') do |file|
        file << to_csv
      end

      save_path
    end

    private

    def range_start_edt
      @range_start_edt ||= range_start.in_time_zone('Eastern Time (US & Canada)')
    end

    def daily_sales_columns
      {
        without_formatting: %w[site_visits total_visitors applications_started submissions leads conversions],
        percent: %w[conversions_percentage],
        money: %w[total_premiums partner_commissions get_covered_commissions]
      }
    end

    def periods
      %w[yesterday prior_seven_days prior_thirty_days]
    end

    def aggregate_report
      get_covered_report = agency_report(Agency.get_covered)

      agencies_reports = Agency.main_agencies.where.not(id: Agency::GET_COVERED_ID).map do |agency|
        agency_report(agency)
      end.compact

      agencies_reports = agencies_reports.sort_by { |row| [row[:agency_data]['any_activity'] ? 0 : 1] }

      flatten_agency_report(get_covered_report)

      agencies_reports.each do |agency_report|
        flatten_agency_report(agency_report)
      end
    end

    def flatten_agency_report(agency_report)
      data['rows'] << agency_report[:agency_data]

      agency_report[:accounts].each do |account_report|
        data['rows'] << account_report
      end

      agency_report[:subagencies].each do |subagency|
        data['rows'] << subagency[:subagency_data]
        subagency[:subagency_accounts].each do |subagency_account_report|
          data['rows'] << subagency_account_report
        end
      end
    end

    def line_data(line_reportable)
      {
        'yesterday' =>
          DailySales.find_by(
            reportable: line_reportable,
            range_start: range_start_edt.yesterday.all_day,
            range_end: range_start_edt.yesterday.all_day
          )&.data,
        'prior_seven_days' => DailySales.find_by(
          reportable: line_reportable,
          range_start: (range_start_edt - 7.days).all_day,
          range_end: range_start_edt.yesterday.all_day
        )&.data,
        'prior_thirty_days' => DailySales.find_by(
          reportable: line_reportable,
          range_start: (range_start_edt - 30.days).all_day,
          range_end: range_start_edt.yesterday.all_day
        )&.data
      }
    end

    def agency_report(agency = reportable)
      agency_report = item_report(agency)

      return unless agency_report.present?

      accounts_reports = agency.accounts.map do |account|
        item_report(account)
      end.compact

      subagencies_reports = agency.agencies.map do |subagency|
        subagency_report = item_report(subagency)

        next unless subagency_report.present?

        subagency_accounts_reports =
          subagency.accounts.map do |account|
            item_report(account)
          end.compact

        {
          subagency_data: item_report(subagency),
          subagency_accounts: subagency_accounts_reports.sort_by { |row| [row['any_activity'] ? 0 : 1] }
        }
      end.compact

      {
        agency_data: agency_report,
        subagencies: subagencies_reports.sort_by { |row| [row[:subagency_data]['any_activity'] ? 0 : 1] },
        accounts: accounts_reports.sort_by { |row| [row['any_activity'] ? 0 : 1] }
      }
    end

    def item_report(item)
      item_data = line_data(item)

      # ignore if we did not generated reports or partner inactive and  all columns are zeroes
      return if item_data.value?(nil) || (!item.enabled? && item_data.values.map(&:values).flatten.uniq == [0])

      update_totals(item_data) unless reportable.is_a?(Account)

      {
        'title' => item.title,
        'type' => item.is_a?(Agency) && item.agency_id.present? ? 'Sub-Agency' : item.class.to_s,
        'id' => item.id,
        'parent_agency' => item.agency&.title,
        'status' => item.enabled? ? 'Active' : 'Inactive',
        'data' => item_data,
        'any_activity' => item_data.values.map(&:values).flatten.uniq != [0]
      }
    end

    def update_totals(line_data)
      line_data.each do |period, period_data|
        period_data.each do |key, value|
          data['totals'][period][key] += value unless key == 'conversions_percentage'
        end
      end
    end

    def calculate_total_conversion_percentages
      periods.each do |period|
        data['totals'][period]['conversions_percentage'] =
          if data['totals'][period]['total_visitors'] != 0
            (data['totals'][period]['conversions'].to_f / data['totals'][period]['total_visitors'].to_f * 100).
              round(1)
          else
            0
          end
      end
    end

    def set_defaults
      self.duration = 'day'
      self.data     = {
        'totals' => {
          'yesterday' => {
            'site_visits' => 0,
            'total_visitors' => 0,
            'applications_started' => 0,
            'submissions' => 0,
            'leads' => 0,
            'conversions' => 0,
            'total_premiums' => 0,
            'partner_commissions' => 0,
            'get_covered_commissions' => 0,
            'conversions_percentage' => 0
          },
          'prior_seven_days' => {
            'site_visits' => 0,
            'total_visitors' => 0,
            'applications_started' => 0,
            'submissions' => 0,
            'leads' => 0,
            'conversions' => 0,
            'total_premiums' => 0,
            'partner_commissions' => 0,
            'get_covered_commissions' => 0,
            'conversions_percentage' => 0
          },
          'prior_thirty_days' => {
            'site_visits' => 0,
            'total_visitors' => 0,
            'applications_started' => 0,
            'submissions' => 0,
            'leads' => 0,
            'conversions' => 0,
            'total_premiums' => 0,
            'partner_commissions' => 0,
            'get_covered_commissions' => 0,
            'conversions_percentage' => 0
          }
        },
        'rows' => []
      }
    end
  end
end
