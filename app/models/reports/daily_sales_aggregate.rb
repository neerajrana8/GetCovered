module Reports
  class DailySalesAggregate < ::Report
    NAME = 'Daily Sales Aggregate Report'.freeze

    def generate
      if reportable.nil?
        aggregate_report
      elsif reportable.is_a?(Agency)
        agency_report
      end

      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << [
          'Total', 'Type', 'Parent Agency', 'Status',
          '', '', '', '', '', '', '', '', '', '',
          '', '', '', '', '', 'Prior 7 Days', '', '', '', '',
          '', '', '', '', '', 'Prior 30 Days', '', '', '', ''
        ]

        csv << [
          '', '', '', '',
          '', '', '', '', '', range_start.yesterday.to_date, '', '', '', '',
          '', '', '', '', '', "(#{(range_start - 7.days).to_date}  - #{range_start.yesterday.to_date})", '', '', '', '',
          '', '', '', '', '', "(#{(range_start - 30.days).to_date} - #{range_start.yesterday.to_date})", '', '', '', ''
        ]
        csv << [
          '', '', '', '',
          'Site Visits', 'Total Visitors', 'Apps Started', 'Subm', 'Leads', 'Conv', 'Conv %', 'Total Premiums', 'Partner Comm\'n', 'GC Comm\'n',
          'Site Visits', 'Total Visitors', 'Apps Started', 'Subm', 'Leads', 'Conv', 'Conv %', 'Total Premiums', 'Partner Comm\'n', 'GC Comm\'n',
          'Site Visits', 'Total Visitors', 'Apps Started', 'Subm', 'Leads', 'Conv', 'Conv %', 'Total Premiums', 'Partner Comm\'n', 'GC Comm\'n'
        ]

        csv << [
          'TOTAL', '', '', '',
          *data['totals']['yesterday'].values_at(*daily_sales_headers),
          *data['totals']['prior_seven_days'].values_at(*daily_sales_headers),
          *data['totals']['prior_thirty_days'].values_at(*daily_sales_headers)
        ]

        data['rows'].each do |row|
          csv << [
            *row.values_at(*%w[title type parent_agency]), row['status'] ? 'Active' : 'Inactive',
            *row['data']['yesterday'].values_at(*daily_sales_headers),
            *row['data']['prior_seven_days'].values_at(*daily_sales_headers),
            *row['data']['prior_thirty_days'].values_at(*daily_sales_headers)
          ]
        end
      end
    end

    def generate_csv
      document_title = "#{reportable&.title || 'All partners'}-Daily-Report-#{range_start.strftime('%B %-d %Y')}.csv".downcase
                                                                                                   .tr(' ', '-')
      save_path = Rails.root.join('tmp', document_title)

      File.open(save_path, 'wb') do |file|
        file << to_csv
      end

      save_path
    end

    private

    def daily_sales_headers
      %w[site_visits total_visitors applications_started submissions leads conversions
         total_premiums partner_commissions get_covered_commissions conversions_percentage]
    end

    def aggregate_report
      agency_report(Agency.get_covered)
      Agency.where.not(id: Agency::GET_COVERED_ID).each do |agency|
        agency_report(agency)
      end
    end

    def line_data(line_reportable)
      {
        'yesterday' =>
          DailySales.find_by(
            reportable: line_reportable,
            range_start: range_start.yesterday.all_day,
            range_end: range_start.yesterday.all_day
          )&.data,
        'prior_seven_days' => DailySales.find_by(
          reportable: line_reportable,
          range_start: (range_start - 7.days).all_day,
          range_end: range_start.yesterday.all_day
        )&.data,
        'prior_thirty_days' => DailySales.find_by(
          reportable: line_reportable,
          range_start: (range_start - 30.days).all_day,
          range_end: range_start.yesterday.all_day
        )&.data
      }
    end

    def agency_report(agency = reportable)
      add_item_report(agency)
      agency.accounts.each do |account|
        add_item_report(account)
      end

      agency.agencies.each do |subagency|
        add_item_report(subagency)
        subagency.accounts.each do |account|
          add_item_report(account)
        end
      end
    end

    def add_item_report(item)
      item_data = line_data(item)

      return if item_data.value?(nil)

      data['rows'] << {
        'title' => item.title,
        'type' => item.class.to_s,
        'id' => item.id,
        'parent_agency' => item.agency&.title,
        'status' => item.enabled,
        'data' => item_data
      }

      update_totals(item_data)
    end

    def update_totals(line_data)
      line_data.each do |period, period_data|
        period_data.each do |key, value|
          if key == 'conversions_percentage'
            data['totals'][period][key] = ((data['totals'][period][key] + value) / 2.0).round(2)
          else
            data['totals'][period][key] += value
          end
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
