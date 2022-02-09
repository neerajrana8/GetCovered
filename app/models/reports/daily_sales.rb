module Reports
  class DailySales < ::Report
    NAME = 'Daily Sales Report'.freeze

    def generate
      self.data = {
        'site_visits' => site_visits,
        'total_visitors' => total_visitors,
        'applications_started' => applications_started,
        'submissions' => submissions,
        'leads' => leads,
        'conversions' => conversions,
        'total_premiums' => total_premiums,
        'partner_commissions' => partner_commissions,
        'get_covered_commissions' => get_covered_commissions
      }

      data['conversions_percentage'] =
        if data['total_visitors'].positive?
          (data['conversions'].to_f / data['total_visitors'].to_f * 100).round(2)
        else
          0
        end

      self
    end

    private

    def set_defaults
      self.duration = 'range'
    end

    def site_visits
      visits = 0
      all_reportable_leads.each do |lead|
        visits +=
          lead.lead_events.where(created_at: range_start..range_end).
            order('DATE(created_at)').
            group('DATE(created_at)').
            count.keys.size
      end

      visits
    end

    def total_visitors
      all_reportable_leads.count
    end

    def applications_started
      all_reportable_leads.
        not_converted.
        where.not(last_visited_page: [Lead::PAGES_RENT_GUARANTEE[0], Lead::PAGES_RESIDENTIAL[0]]).
        count
    end

    def submissions
      all_reportable_leads.
        not_converted.where(last_visited_page: [Lead::PAGES_RENT_GUARANTEE.last, Lead::PAGES_RESIDENTIAL.last]).
        count
    end

    def conversions
      all_reportable_leads.converted.
        joins(user: :policies).
        where(policies: { created_at: range_start..range_end }).
        count
    end

    def leads
      all_reportable_leads.not_converted.count
    end

    def total_premiums
      line_item_changes.inject(0) { |sum, com| sum + com.amount }
    end

    def partner_commissions
      commissions(reportable)
    end

    def get_covered_commissions
      commissions(Agency.get_covered)
    end

    def commissions(recipient)
      CommissionItem.
        references(:commissions).
        includes(:commission).
        where(
          reason: line_item_changes,
          analytics_category: %w[policy_premium master_policy_premium],
          commissions: { recipient: recipient }
        ).
        inject(0) { |sum, com| sum + com.amount }
    end

    def line_item_changes
      LineItemChange.
        joins(line_item: :invoice).
        joins("inner join policy_quotes on (invoices.invoiceable_type = 'PolicyQuote' and invoices.invoiceable_id = policy_quotes.id)").
        where(
          created_at: range_start..range_end,
          field_changed: :total_received,
          analytics_category: %w[policy_premium master_policy_premium]
        ).
        where("policy_quotes.policy_id IN (#{all_reportable_policies.select(:id).to_sql})")
    end

    def all_reportable_leads
      query =
        case reportable_type
        when 'Agency'
          Lead.where(agency: reportable_id, account_id: nil)
        when 'Account'
          Lead.where(account: reportable_id)
        end
      query.where(last_visit: range_start..range_end)
    end

    def all_reportable_policies
      case reportable_type
      when 'Agency'
        Policy.where(agency: reportable_id, account_id: nil)
      when 'Account'
        Policy.where(account: reportable_id)
      end
    end
  end
end
