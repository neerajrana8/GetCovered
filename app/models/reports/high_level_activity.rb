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
  # This report is available for agencies and accounts.
  # Maximum communities in report is ~1_000_000, because jsonb can't store JSON bigger than ~200MB.
  class HighLevelActivity < ::Report
    NAME = 'High Level Activity'.freeze
    # @todo Rewrite using builder pattern, because now reports know about the class for what we generate this report
    # I planned to make reports "class agnostic".
    def generate
      communities = reportable.insurables.communities
      last_report = reportable.reports.where(type: self.class.to_s).order(created_at: :desc).first

      communities.each do |community|
        current_community_data = community.coverage_report
        common_properties = {
          'insurable_id' => community.id,
          'property_name' => community.title,
          'total_units' => current_community_data[:unit_count],
          'total_active' => current_community_data[:covered_count],
          'total_pending_cancellation' => total_pending_cancellation(community),
          'total_cancelled' => current_community_data[:cancelled_policy_count],
          'total_third_party' => current_community_data[:policy_external_covered_count]
        }
        changes =
          if last_report.present?
            old_row_data = last_report.data['rows'].find { |row| row['insurable_id'] == community.id }
            if old_row_data.present?
              {
                'added' => current_community_data[:covered_count] - old_row_data['total_active'],
                'canceled' => current_community_data[:cancelled_policy_count] - old_row_data['total_cancelled'],
                'third_party_added' => current_community_data[:policy_external_covered_count] - old_row_data['total_third_party'],
              }
            else
              {
                'added' => current_community_data[:covered_count],
                'canceled' => current_community_data[:cancelled_policy_count],
                'third_party_added' => current_community_data[:policy_external_covered_count],
              }
            end
          else
            {
              'added' => nil,
              'canceled' => nil,
              'third_party_added' => nil,
            }
          end
        self.data['rows'] << common_properties.merge(changes)
      end

      self
    end

    def column_names
      {
        'property_name' => 'Property Name',
        'added' => 'Added',
        'canceled' => 'Canceled',
        'third_party_added' => '3rd Party Added ',
        'total_units' => 'Total Units',
        'total_active' => 'Total Active',
        'total_pending_cancellation' => 'Total Pending Cancellation',
      }
    end

    def headers
      %w[property_name added canceled third_party_added total_units total_active total_pending_cancellation]
    end

    private

    def set_defaults
      self.data ||= { rows: [] }
    end

    def total_pending_cancellation(insurable)
      units = insurable.units
      if units.present?
        units.reduce(0) do |count, unit|
          policy = unit.policies.take
          policy.present? && policy.billing_status == 'BEHIND' ? count + 1 : count
        end
      else
        0
      end
    end
  end
end
