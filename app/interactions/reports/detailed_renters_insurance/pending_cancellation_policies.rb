module Reports
  module DetailedRentersInsurance
    # Active Policies Report for Cambridge
    # if reportable is nil generates reports for all agencies and accounts
    # in other cases it generate report for object that has two required methods or relations : reports and  insurables
    class PendingCancellationPolicies < ActiveInteraction::Base
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

        Report.create(format: 'detailed_renters_insurance::pending_cancellation_policies',
                      data: data,
                      reportable: agency)
      end

      def prepare_report(reportable)
        data = { 'rows' => [] }
        reportable.insurables.units.covered.each do |insurable|
          policy = insurable.policies.take

          if policy.present? && policy.billing_status == :BEHIND
            data['rows'] << {
              address: insurable.title,
              primary_user: policy.primary_user&.profile&.full_name,
              policy_type: 'H04',
              policy: policy.number,
              cancel_reason: 'Behind billing',
              pending_cancel_date: policy
            }
          end
        end

        Report.create(format: 'detailed_renters_insurance::pending_cancellation_policies',
                      data: data,
                      reportable: reportable)
      end
    end
  end
end
