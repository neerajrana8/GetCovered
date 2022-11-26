# == Schema Information
#
# Table name: reports
#
#  id              :bigint           not null, primary key
#  duration        :integer
#  range_start     :datetime
#  range_end       :datetime
#  data            :jsonb
#  reportable_type :string
#  reportable_id   :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  type            :string
#
module Reports
  # This report is available for accounts.
  class HighLevelTrendAnalysis < ::Report
    NAME = 'High Level Trend Analysis'.freeze

    def available_formats
      %w[csv xlsx]
    end

    def generate
      self.data = {
        'portfolio_wide_participation_trend' => portfolio_participation_trend(reportable),
        'communities' => communities_data
      }
      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << ['INDIVIDUAL PROPERTY RENTERS INSURANCE TREND ANALYSIS']
        csv << []
        self.data['communities'].sort { |x, y| y['current_participation_rate'] <=> x['current_participation_rate'] }.each do |community|
          csv << ['Property title: ', community['title']]
          csv << ['Current participation rate(%):', community['current_participation_rate']]
          csv << []
          community['participation_trend'].sort { |x, y| y['year'] <=> x['year'] }.each do |year|
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


        csv << ['PORTFOLIO WIDE TREND ANALYSIS']
        csv << []

        self.data['portfolio_wide_participation_trend'].sort { |x, y| y['year'] <=> x['year'] }.each do |year|
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
      ::Axlsx::Package.new do |p|
        wb = p.workbook
        wb.add_worksheet(:name => "Individual trend analysis") do |sheet|
          sheet.add_row ['INDIVIDUAL PROPERTY RENTERS INSURANCE TREND ANALYSIS']
          sheet.add_row []
          self.data['communities'].sort { |x, y| y['current_participation_rate'] <=> x['current_participation_rate'] }.each do |community|
            sheet << ['Property title: ', community['title']]
            sheet << ['Current participation rate(%):', community['current_participation_rate']]
            sheet << []
            community['participation_trend'].sort { |x, y| y['year'] <=> x['year'] }.each do |year|
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
              total = sheet.add_row total_participation
              account = sheet.add_row account_participation
              third_party = sheet.add_row third_party_participation
              chart = sheet.add_chart(
                Axlsx::LineChart,
                :title => "Trends #{year['year']}",
                :show_legend => true,
                :start_at => [0, third_party.row_index + 1],
                :end_at => [6, third_party.row_index + 10]
              )
              chart.add_series(data: total[1..-1], title: total[0])
              chart.add_series(data: account[1..-1], title: account[0])
              chart.add_series(data: third_party[1..-1], title: third_party[0])
              12.times { sheet.add_row [] }
            end
          end
        end

        wb.add_worksheet(:name => "Portfolio wide analysis") do |sheet|
          sheet.add_row ['PORTFOLIO WIDE TREND ANALYSIS']
          sheet.add_row []
          self.data['portfolio_wide_participation_trend'].sort { |x, y| y['year'] <=> x['year'] }.each do |year|
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
            total = sheet.add_row total_participation
            account = sheet.add_row account_participation
            third_party = sheet.add_row third_party_participation
            chart = sheet.add_chart(
              Axlsx::LineChart,
              :title => "Trends #{year['year']}",
              :start_at => [0, third_party.row_index + 1],
              :end_at => [6, third_party.row_index + 10]
            )
            chart.add_series(data: total[0..-1], title: 'Total participation %')
            chart.add_series(data: account[0..-1], title: 'Internal participation %')
            chart.add_series(data: third_party[0..-1], title: 'Third party participation %')
            12.times { sheet.add_row [] }
          end
        end
      end.to_stream
    end

    private

    def portfolio_participation_trend(object)
      if ::Reports::Coverage.where(reportable: object).present?
        report_years(object).map { |year| portfolio_wide_year(object, year) }
      else
        []
      end
    end

    def report_years(object)
      first_report_date = ::Reports::Coverage.where(reportable: object).order(:created_at).first.created_at
      last_report_date = ::Reports::Coverage.where(reportable: object).order(created_at: :desc).first.created_at
      (first_report_date.year..last_report_date.year).to_a
    end

    def portfolio_wide_year(object, year)
      report_range = Time.zone.local(year).beginning_of_year..Time.zone.local(year).end_of_year
      coverage_reports = ::Reports::Coverage.where(reportable: object, created_at: report_range).order(:created_at)
      {
        'year' => year,
        'data' => coverage_reports.map(&method(:date_coverage_data))
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

    def communities_data
      communities = reportable.insurables.communities
      communities.map(&method(:community_report))
    end

    def community_report(community)
      current_coverage_report = community.coverage_report
      current_participation_rate =
        (current_coverage_report[:covered_count].to_f / current_coverage_report[:unit_count] * 100).round(2)
      {
        'id' => community.id,
        'title' => community.title,
        'current_participation_rate' => current_participation_rate,
        'participation_trend' => portfolio_participation_trend(community)
      }
    end

    def set_defaults
      self.data ||= {
        'portfolio_wide_participation_trend' => []
      }
    end
  end
end
