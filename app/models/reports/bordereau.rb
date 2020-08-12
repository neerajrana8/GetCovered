# This report is only for agencies and accounts
module Reports
  class Bordereau < ::Report
    NAME = 'Bordereau'.freeze

    def generate
      self.data['rows'] = rows
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
        'tenant_name' => 'TenantName',
        'tenant_address' => 'TenantAddress',
        'tenant_unit' => 'TenantUnit',
        'tenant_city' => 'TenantCity',
        'tenant_state' => 'TenantState',
        'tenant_zip' => 'TenantZipCode',
        'unit_state' => 'Risk_State',
        'transaction' => 'Transaction',
        'effective_date' => 'Eff_Date',
        'expiration_date' => 'Exp_Date',
        'cancellation_date' => 'Canc_date',
        'liability_limit' => 'Tenant_Liability_Limit',
        'coverage_c_limit' => 'Tenant_CovC_Limit',
      }
    end

    def headers
      %w[master_policy_number master_policy_coverage_number agent_id agent_email
         property_manager_id property_manager_name property_manager_email community_name community_id unit_id tenant_id
         tenant_email tenant_name tenant_address tenant_unit tenant_city tenant_state tenant_zip unit_state transaction
         effective_date expiration_date cancellation_date liability_limit coverage_c_limit]
    end

    private

    def rows
      coverages.map {|community| community_report_data(community)}
    end

    def coverages
      base_query
      coverages ||=
        if reportable.blank?
            Policies.where(coverages_condition, range_start: range_start, range_end: range_end)
        elsif reportable.is_a? Account
          Policies.where(coverages_condition, range_start: range_start, range_end: range_end)
        elsif reportable.is_a? Agency
          Policies.where(coverages_condition, range_start: range_start, range_end: range_end, agency)
        end
      reportable.insurables.communities
    end

    def coverages_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end) 
        OR (expiration_date > :range_start AND expiration_date < :range_end) 
        OR (effective_date >= :range_start AND effective_date < :range_end)
      SQL
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

    def set_defaults
      self.data ||= {
        'rows' => []
      }
    end
  end
end
