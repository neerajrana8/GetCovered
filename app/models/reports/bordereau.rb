# This report is only for agencies and accounts
module Reports
  class Bordereau < ::Report
    NAME = 'Bordereau'.freeze

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
        'master_policy_number' => 'MasterPolicyNumber',
        'master_policy_coverage_number' => 'CertificateNumber',
        'agent_id' => 'AgentID',
        'agent_email' => 'AgentEmail',
        'property_manager_id' => 'PropMgrID',
        'property_manager_name' => 'PropMgrName',
        'property_manager_email' => 'PropMgrEmail',
        'community_name' => 'CommunityName',
        'community_id' => 'CommunityID',
        'unit_id' => 'UnitID',
        'tenant_id' => 'TenantID',
        'tenant_email' => 'TenantEmail',
        'tenant_name' => 'TenantID',
        'tenant_address' => 'TenantID',
        'tenant_unit' => 'TenantID',
        'tenant_city' => 'TenantID',
        'tenant_state' => 'TenantState',
        'tenant_zip' => 'TenantZipCode',
        'tenant_zip' => 'TenantZipCode',
        'tenant_zip' => 'TenantZipCode',
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

    def last_month_report
      @last_month_report ||= Reports::HighLevelParticipation.where(reportable: reportable).order(created_at: :desc).first
    end

    def community_report_data(community)
      participation_report_data = ::Reports::Participation.new(reportable: community).generate.data
      last_month_data = last_month_community_data(community)

      {
        'insurable_id' => community.id,
        'property_name' => community.primary_address&.full,
        'current_participation' => participation_report_data['participation_rate'],
        'last_month_participation' => last_month_data[:participation],
        'change_in_participation' => participation_report_data['participation_rate'] - last_month_data[:participation].to_f,
        'participation_trend' => participation_trend(participation_report_data['participation_rate'], last_month_data[:participation]),
        'current_in_system_participation' => participation_report_data['in_system_participation_rate'],
        'last_month_in_system_participation' => last_month_data[:in_system],
        'change_in_system_participation' => participation_report_data['in_system_participation_rate'] - last_month_data[:in_system].to_f,
        'current_3rd_party_participation' => participation_report_data['3rd_party_participation_rate'],
        'last_month_3rd_party_participation' => last_month_data[:third_party],
        'change_3rd_party_participation' => participation_report_data['3rd_party_participation_rate'] - last_month_data[:third_party].to_f,
        'total_in_system_active_policies' => participation_report_data['number_active_system_policies'],
        'total_3rd_party_active_policies' => participation_report_data['number_active_3rd_party_policies']
      }
    end

    def participation_trend(participation, last_month_participation)
      if last_month_participation
        if participation > last_month_participation.to_f.round(2)
          'up'
        elsif participation < last_month_participation.to_f.round(2)
          'down'
        else
          'not changed'
        end
      else
        nil
      end
    end

    def last_month_community_data(community)
      if last_month_report.present?
        row_data = last_month_report.data['rows'].detect{ |row| row['insurable_id'] == community.id }
        if row_data.present?
          {
            participation: row_data['current_participation'],
            in_system: row_data['current_in_system_participation'],
            third_party: row_data['current_3rd_party_participation']
          }
        else
          {
            participation: nil,
            in_system: nil,
            third_party: nil
          }
        end
      else
        {
          participation: nil,
          in_system: nil,
          third_party: nil
        }
      end
    end

    def total
      total_report = ::Reports::Participation.new(reportable: reportable).generate.data
      {
        'covered' => total_report['number_covered_units'],
        'in_system_covered' => total_report['number_covered_in_system'],
        'uncovered' => total_report['number_uncovered'],
        'units' => total_report['total_units'],
        'participation' => total_report['participation_rate'],
        'in_system_participation' => total_report['in_system_participation_rate'],
        '3rd_party_participation' => total_report['3rd_party_participation_rate'],
        'active_in_system_policies' => total_report['number_active_system_policies'],
        'active_3rd_party_policies' => total_report['number_active_3rd_party_policies']
      }
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
