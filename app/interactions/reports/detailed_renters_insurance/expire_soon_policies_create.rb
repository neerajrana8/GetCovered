module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # if reportable is nil generates reports for all agencies and accounts
    # in other cases it generate report for object that has two required methods or relations : reports and  insurables
    class ExpireSoonPoliciesCreate < ActiveInteraction::Base
      interface :reportable, methods: %i[reports insurables], default: nil

      def execute
        if reportable.nil?
          prepare_agencies_reports
        else
          prepare_report(reportable)
        end
      end

      private

      def prepare_agencies_reports
        Agency.where(enabled: true).each do |agency|
          prepare_agency_report(agency)
        end
      end

      def prepare_agency_report(agency)
        data = { 'rows' => [] }

        agency.accounts.each do |account|
          account_report = prepare_report(account)
          data['rows'] += account_report.data['rows']
        end

        Reports::DetailedRentersInsurance::ExpireSoonPolicies.create(data: data, reportable: agency)
      end

      def prepare_report(reportable)
        data = { 'rows' => [] }

        reportable.insurables.communities.each do |insurable|
          community_report_data = prepare_community_report(insurable)
          data['rows'] += community_report_data['rows']
        end

        Reports::DetailedRentersInsurance::ExpireSoonPolicies.create(data: data, reportable: reportable)
      end

      def prepare_community_report(insurable_community)
        data = { 'rows' => [] }
        insurable_community.units.each do |unit|
          policy = unit.policies.take
          if (policy&.auto_renew == false) && (policy&.expiration_date < Time.current + 30.days)
            data['rows'] << {
              address: unit.title,
              primary_user: policy.primary_user&.profile&.full_name,
              policy_type: 'H04',
              policy: policy.number,
              expiration_date: policy.expiration_date
            }
          end
        end
        Reports::DetailedRentersInsurance::ExpireSoonPolicies.create(data: data, reportable: insurable_community)
        data
      end
    end
  end
end
