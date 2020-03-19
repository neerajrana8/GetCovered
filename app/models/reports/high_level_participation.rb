# This report is only for agencies and accounts
module Reports
  class HighLevelParticipation < ::Report
    def generate
      self.data['rows'] = rows
      self.data['total'] = total
      self
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        total_names.keys.each do |field|
          csv << [total_names[field], self.data['total'][field]]
        end

        csv << []

        csv << headers.map{|header| column_names[header]}
        data['rows'].each do |row|
          table_row = []
          headers.each do |attr|
            ap row["#{attr}"]
            table_row << row["#{attr}"]
          end
          csv << table_row
        end
      end
    end

    def column_names
      {
        'property_name' => 'Property Name',
        'current_participation' => 'Current Participation',
        'last_month_participation' => 'Last Month Participation',
        'change_in_participation' => 'Change in Participation',
        'participation_trend' => 'Participation trend',
        'current_in_system_participation' => 'Current agency Participation',
        'last_month_in_system_participation' => 'Last month Agency Participation',
        'change_in_system_participation' => 'Change in Agency Participation',
        'current_3rd_party_participation' => 'Current 3rd party Participation',
        'last_month_3rd_party_participation' => 'Last month 3rd party Participation',
        'change_3rd_party_participation' => 'Change in 3rd party Participation',
        'total_in_system_active_policies' => 'Total In-Force Agency Policies',
        'total_3rd_party_active_policies' => 'Total In-Force 3rd Party Policies'
      }
    end

    def total_names
      {
        'covered' => 'Total Covered Units Portfolio Wide',
        'in_system_covered' => 'Total Occupant Shield Covered Units Portfolio Wide',
        'uncovered' => 'Total Uncovered Units Portfolio Wide',
        'units' => 'Total Units Portfolio Wide',
        'participation' => 'Total Portfolio Wide Participation(Agency and 3rd party)',
        'in_system_participation' => 'Total Portfolio Wide Occupant Shield Participation',
        '3rd_party_participation' => 'Total Portfolio Wide 3rd Party Participation',
        'active_in_system_policies' => 'Total Portfolio Wide Active Occupant Shield Policies',
        'active_3rd_party_policies' => 'Total Portfolio Wide Active 3rd Party Policies'
      }
    end

    def headers
      %w[property_name current_participation last_month_participation change_in_participation
      participation_trend current_in_system_participation last_month_in_system_participation
      change_in_system_participation current_3rd_party_participation last_month_3rd_party_participation
      change_3rd_party_participation total_in_system_active_policies total_3rd_party_active_policies]
    end

    private

    def rows
      communities.map {|community| community_report_data(community)}
    end

    def communities
      reportable.insurables.communities
    end

    def community_report_data(community)
      {
        'property_name' => community.primary_address.full,
        'current_participation' => 'Current Participation',
        'last_month_participation' => 'Last Month Participation',
        'change_in_participation' => 'Change in Participation',
        'participation_trend' => 'Participation trend',
        'current_in_system_participation' => 'Current agency Participation',
        'last_month_in_system_participation' => 'Last month Agency Participation',
        'change_in_system_participation' => 'Change in Agency Participation',
        'current_3rd_party_participation' => 'Current 3rd party Participation',
        'last_month_3rd_party_participation' => 'Last month 3rd party Participation',
        'change_3rd_party_participation' => 'Change in 3rd party Participation',
        'total_in_system_active_policies' => 'Total In-Force Agency Policies',
        'total_3rd_party_active_policies' => 'Total In-Force 3rd Party Policies'
      }
    end

    def total

    end

    def set_defaults
      self.data ||= {
        'rows' => [],
        'total' => {
          'covered' => 0,
          'in_system_covered' => 0,
          'uncovered' => 0,
          'units' => 0,
          'participation' => 0,
          'in_system_participation' => 0,
          '3rd_party_participation' => 0,
          'active_in_system_policies' => 0,
          'active_3rd_party_policies' => 0
        }
      }
    end
  end
end
