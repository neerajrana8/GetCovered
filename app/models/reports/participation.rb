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
  class Participation < ::Report
    NAME = 'Participation'.freeze

    def generate
      self.data = report_data
      self
    end

    def to_csv
      CSV.generate do |csv|
        fields.each do |field|
          csv << [column_names[field], self.data[field]]
        end
      end
    end

    def fields
      %w[
         last_month_participation
         participation_rate
         participation_trend
         occupied_participation_rate
         occupied_participation_trend
         in_system_participation_rate
         3rd_party_participation_rate
         total_units
         total_occupied_units
         number_covered_units
         number_covered_in_system
         number_uncovered
         number_active_system_policies
         number_active_3rd_party_policies
      ]
    end

    # There can be implemented a localization
    def column_names
      {
        'last_month_participation' => 'Last month participation rate',
        'participation_rate' => 'Participation rate',
        'participation_trend' => 'Participation trend',
        'occupied_participation_rate' => 'Participation rate(occupied units)',
        'occupied_participation_trend' => 'Participation trend(occupied units)',
        'in_system_participation_rate' => 'Current Agency Participation Rate(%)',
        '3rd_party_participation_rate' => 'Current 3rd Party Participation Rate',
        'total_units' => 'Total units',
        'total_occupied_units' => 'Total occupied units',
        'number_covered_units' => 'Number covered units',
        'number_covered_in_system' => 'Number covered units by the agency',
        'number_uncovered' => 'Number uncovered units',
        'number_active_system_policies' => 'Number of In-Force Agency Policies',
        'number_active_3rd_party_policies' => 'Number of In-Force 3rd Party Policies'
      }
    end

    private

    def report_data
      {
        'last_month_participation' => last_month_participation,
        'participation_rate' => participation_rate,
        'participation_trend' => participation_trend,
        'occupied_participation_rate' => occupied_participation_rate,
        'occupied_participation_trend' => occupied_participation_trend,
        'in_system_participation_rate' => in_system_participation_rate,
        '3rd_party_participation_rate' => external_participation_rate,
        'total_units' => coverage_report[:unit_count],
        'total_occupied_units' => coverage_report[:occupied_count],
        'number_covered_units' => coverage_report[:covered_count],
        'number_covered_in_system' => coverage_report[:policy_internal_covered_count],
        'number_uncovered' => coverage_report[:unit_count] - coverage_report[:covered_count],
        'number_active_system_policies' => number_active_system_policies,
        'number_active_3rd_party_policies' => number_active_3rd_party_policies
      }
    end

    def coverage_report
      @coverage_report ||= reportable.coverage_report
    end

    def reportable_units
      if reportable.is_a?(Insurable)
        reportable.units
      else
        reportable.insurables.units
      end
    end

    def participation_rate
      if coverage_report[:unit_count] > 0
        (coverage_report[:covered_count].to_f / coverage_report[:unit_count] * 100).round(2)
      else
        0
      end
    end

    def participation_trend
      if last_month_report.present?
        if participation_rate > last_month_report.data['participation_rate'].to_f.round(2)
          'up'
        elsif participation_rate < last_month_report.data['participation_rate'].to_f.round(2)
          'down'
        else
          'not changed'
        end
      else
        nil
      end
    end

    def occupied_participation_rate
      if coverage_report[:occupied_count] > 0
        (coverage_report[:occupied_covered_count].to_f / coverage_report[:occupied_count] * 100).round(2)
      else
        0
      end
    end

    def occupied_participation_trend
      if last_month_report.present?
        if occupied_participation_rate > last_month_report.data['occupied_participation_rate'].to_f.round(2)
          'up'
        elsif occupied_participation_rate < last_month_report.data['occupied_participation_rate'].to_f.round(2)
          'down'
        else
          'not changed'
        end
      else
        nil
      end
    end

    def in_system_participation_rate
      if coverage_report[:occupied_count] > 0
        (coverage_report[:policy_internal_covered_count].to_f / coverage_report[:unit_count] * 100).round(2)
      else
        0
      end

    end

    def external_participation_rate
      if coverage_report[:occupied_count] > 0
        (coverage_report[:policy_external_covered_count].to_f / coverage_report[:unit_count] * 100).round(2)
      else
        0
      end
    end

    def number_active_system_policies
      if reportable_units.present?
        Policy.
          joins(:insurables).
          where(insurables: { id: reportable_units.map(&:id) }, policies: { policy_in_system: true }).
          where('policies.expiration_date > ?', Time.current).
          distinct.
          count
      else
        0
      end
    end

    def number_active_3rd_party_policies
      if reportable_units.present?
        Policy.
          joins(:insurables).
          where(insurables: { id: reportable_units.map(&:id) }, policies: { policy_in_system: false }).
          where('policies.expiration_date > ?', Time.current).
          distinct.
          count
      else
        0
      end
    end

    def last_month_report
      @last_month_report ||= Reports::Participation.where(reportable: reportable).order(created_at: :desc).first
    end

    def last_month_participation
      last_month_report ? last_month_report.data['participation_rate'] : nil
    end
  end
end
