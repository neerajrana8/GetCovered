module Reports
  # This report is available for agencies and accounts.
  # Maximum communities in report is ~1_000_000, because jsonb can't store JSON bigger than ~200MB.
  class HighLevelTrendAnalysis < ::Report

    # @todo Rewrite using builder pattern, because now reports know about the class for what we generate this report
    # I planned to make reports "class agnostic".
    def generate
      self.data = {
        'portfolio_wide_participation_trend' => portfolio_wide_participation_trend
      }
      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << ['Portfolio wide participation trend']
        csv << []

        self.data['portfolio_wide_participation_trend'].each do |year|
          csv << ['Year', year['year']]
          days = ['Day']
          total_participation = ['Total participation']
          account_participation = ['Internal participation']
          third_party_participation = ['Third party participation']
          year['data'].each do |day|
            days << day['date']
            total_participation << day['total_participation']
            account_participation << day['account_participation']
            third_party_participation << day['third_party_participation']
          end
          csv << days
          csv << total_participation
          csv << account_participation
          csv << third_party_participation
          csv << []
        end
      end
    end

    def to_xlsx
      Axlsx::Package.new do |p|
        wb = p.workbook
        wb.add_worksheet(:name => "Line Chart") do |sheet|
          sheet.add_row['Portfolio wide participation trend']
          sheet.add_row []
          self.data['portfolio_wide_participation_trend'].each do |year|
            sheet.add_row ['Year', year['year']]
            days = ['Day']
            total_participation = ['Total participation']
            account_participation = ['Internal participation']
            third_party_participation = ['Third party participation']
            year['data'].each do |day|
              days << day['date']
              total_participation << day['total_participation']
              account_participation << day['account_participation']
              third_party_participation << day['third_party_participation']
            end
            sheet.add_row days
            sheet.add_row total_participation
            sheet.add_row account_participation
            sheet.add_row third_party_participation
            sheet.add_row []
          end
        end
        p.serialize('simple.xlsx')
      end
    end

    private

    def portfolio_wide_participation_trend
      if ::Reports::Coverage.where(reportable: reportable).present?
        report_years.map(&method(:portfolio_wide_year))
      else
        []
      end
    end

    def report_years
      first_report_date = ::Reports::Coverage.where(reportable: reportable).order(:created_at).first.created_at
      last_report_date = ::Reports::Coverage.where(reportable: reportable).order(created_at: :desc).first.created_at
      (first_report_date.year..last_report_date.year).to_a
    end

    def portfolio_wide_year(year)
      report_range = Time.zone.local(year).beginning_of_year..Time.zone.local(year).end_of_year
      coverage_reports = ::Reports::Coverage.where(reportable: reportable, created_at: report_range).order(:created_at)
      {
        'year' => year,
        'data' => coverage_reports.map do |report|
          date_coverage_data(report)
        end
      }
    end

    def date_coverage_data(report)
      participation_rates = participation_rates(report.data)
      {
        'date' => report.created_at.to_date,
        'total_participation' => participation_rates[:total],
        'account_participation' => participation_rates[:account],
        'third_party_participation' => participation_rates[:third_party],
      }
    end

    def participation_rates(report_data)
      if report_data['unit_count'] > 0
        {
          total: (report_data['covered_count'].to_f / report_data['unit_count'] * 100).round(2),
          account: (report_data['policy_internal_covered_count'].to_f / report_data['unit_count'] * 100).round(2),
          third_party: (report_data['policy_external_covered_count'].to_f / report_data['unit_count'] * 100).round(2)
        }
      else
        {
          total: 0,
          account: 0,
          third_party: 0
        }
      end
    end

    def set_defaults
      self.data ||= {
        'portfolio_wide_participation_trend' => []
      }
    end
  end
end
