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
# This report is only for agencies and accounts
module Reports
  class Bordereau < ::Report
    NAME = 'Bordereau'.freeze

    def generate
      data['rows'] = rows
      self
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << headers.map { |header| column_names[header] }
        data['rows'].each do |row|
          table_row = []
          headers.each do |attr|
            table_row <<
              if %w[liability_limit coverage_c_limit].include?(attr) && row['landlord_sumplimental'].present?
                value = row[attr.to_s].present? ? format('%.2f', row[attr.to_s].to_i / 100.0) : ''
                "$#{value}"
              else
                row[attr.to_s]
              end
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
        'tenant_city' => 'TenantCity',
        'tenant_state' => 'TenantState',
        'tenant_zip' => 'TenantZipCode',
        'unit_state' => 'Risk_State',
        'transaction' => 'Transaction',
        'effective_date' => 'Eff_Date',
        'expiration_date' => 'Exp_Date',
        'cancellation_date' => 'Canc_date',
        'liability_limit' => 'Tenant_Liability_Limit',
        'coverage_c_limit' => 'Tenant_CovC_Limit'
      }
    end

    def headers
      %w[master_policy_number master_policy_coverage_number agent_id agent_email
         property_manager_id property_manager_name property_manager_email community_name community_id unit_id tenant_id
         tenant_email tenant_name tenant_address tenant_city tenant_state tenant_zip unit_state transaction
         effective_date expiration_date cancellation_date liability_limit coverage_c_limit]
    end

    private

    def rows
      coverages.map { |coverage| row(coverage) }
    end

    def coverages
      base_query =
        Policy.
          includes(:policy, :insurables, :users, :agency, :account, policy: :insurables).
          where(policy_type_id: PolicyType::MASTER_COVERAGES_IDS).
          where(coverages_condition, range_start: range_start, range_end: range_end)
      coverages =
        if reportable.blank?
          base_query
        elsif reportable.is_a? Account
          base_query.where(account: reportable)
        elsif reportable.is_a? Agency
          base_query.where(agency: reportable)
        end
      coverages
    end

    def coverages_condition
      <<-SQL
        (effective_date >= :range_start AND expiration_date < :range_end) 
        OR (expiration_date > :range_start AND expiration_date < :range_end) 
        OR (effective_date >= :range_start AND effective_date < :range_end)
        OR (effective_date < :range_start AND expiration_date >= :range_end)
      SQL
    end

    def row(coverage)
      primary_insurable = coverage.primary_insurable
      tenant = primary_insurable.leases.where(status: 'current').take&.primary_user
      {
        'master_policy_number' => coverage.number,
        'master_policy_coverage_number' => coverage.policy.number,
        'agent_id' => coverage.agency.id,
        'agent_email' => coverage.agency.contact_info[:contact_email],
        'property_manager_id' => coverage.account.id,
        'property_manager_name' => coverage.account.title,
        'property_manager_email' => coverage.account.contact_info[:contact_email],
        'community_name' => primary_insurable&.parent_community&.title,
        'community_id' => primary_insurable&.parent_community&.id,
        'unit_id' => primary_insurable&.id,
        'tenant_id' => tenant&.id,
        'tenant_email' => tenant&.email,
        'tenant_name' => tenant&.profile&.full_name,
        'tenant_address' => tenant&.address&.full,
        'tenant_city' => tenant&.address&.city,
        'tenant_state' => tenant&.address&.state,
        'tenant_zip' => tenant&.address&.zip_code,
        'unit_state' => primary_insurable&.primary_address&.state,
        'transaction' => coverage_transaction(coverage),
        'effective_date' => coverage.expiration_date,
        'expiration_date' => coverage.effective_date,
        'cancellation_date' => coverage.cancellation_date,
        'landlord_sumplimental' => coverage.system_data['landlord_sumplimental'],
        'liability_limit' => liability_limit(coverage),
        'coverage_c_limit' => coverage_c_limit(coverage)
      }
    end

    def coverage_transaction(coverage)
      if coverage.effective_date > range_start
        'New'
      elsif coverage.cancellation_date.present? && coverage.cancellation_date.between?(range_start, range_end)
        'Cancelled'
      else
        'Renew'
      end
    end

    def liability_limit(coverage)
      if coverage.system_data['landlord_sumplimental']
        coverage.policy.policy_coverages.find_by_designation('liability')&.limit
      else
        ''
      end
    end

    def coverage_c_limit(coverage)
      if coverage.system_data['landlord_sumplimental']
        coverage.policy.policy_coverages.find_by_designation('coverage_c')&.limit
      else
        ''
      end
    end

    def set_defaults
      self.data ||= {
        'rows' => []
      }
    end
  end
end
