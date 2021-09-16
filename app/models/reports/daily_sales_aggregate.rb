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

    private

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
