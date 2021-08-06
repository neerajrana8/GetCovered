module PoliciesDashboardMethods
  extend ActiveSupport::Concern

  MAX_COUNTS = 9998

  included do
    before_action :set_policies
  end

  def total
    apply_filters(:@filtered_policies, @policies)
    lics = line_item_changes(@filtered_policies, date_params[:start]...date_params[:end])
    total_premium_paid = premium_collected(lics)
    bound_policies = bound_policy_count(@filtered_policies)

    @total = {
      total_policies_sold: {
        bound: bound_policies,
        cancelled: cancelled_policy_count(@filtered_policies),
        total_premium_paid: total_premium_paid,
        average_premium_paid: (total_premium_paid.to_f / bound_policies).round,
        total_commission: commissions_collected(lics)
      }
    }

    render json: @total.to_json
  end

  def graphs
    start_date = Date.parse(date_params[:start])
    end_date   = Date.parse(date_params[:end])

    @graphs = {
      total_new_policies: 0,
      by_policy_type: Hash.new(0),
      graphs: {}
    }

    if filter_by_day?(start_date, end_date)
      start_date.upto(end_date) do |date|
        params[:filter][:created_at] = Date.parse(date.to_s).all_day
        apply_filters(:@policies_by_day, @policies)
        set_day_data(@policies_by_day, date)
      end
    else
      while start_date < end_date
        params[:filter][:created_at] = start_date.all_month
        apply_filters(:@policies_by_month, @policies)
        set_day_data(@policies_by_month, start_date.end_of_month)
        start_date += 1.month
      end
    end

    render json: @graphs.to_json
  end

  private

  def set_policies
    @policies = Policy.not_master
  end

  def set_day_data(policies, date)
    lics = line_item_changes(policies, params[:filter][:created_at])
    @graphs[:graphs][date.to_s] = {
      total_new_policies: total_new_policies(policies),
      by_policy_type: by_policy_type(policies),
      premium_collected: premium_collected(lics),
      commissions_collected: commissions_collected(lics)
    }

    @graphs[:total_new_policies] += @graphs[:graphs][date.to_s][:total_new_policies]
    @graphs[:graphs][date.to_s][:by_policy_type].each do |id, count|
      @graphs[:by_policy_type][id] += count
    end
  end

  def bound_policy_count(policies)
    policies.current.count
  end

  def cancelled_policy_count(policies)
    policies.where(status: 'CANCELLED').count
  end

  def total_new_policies(policies_relation)
    policies_relation.count
  end

  def by_policy_type(policies)
    PolicyType.where.not(id: PolicyType::MASTER_TYPES_IDS).each_with_object({}) do |policy_type, result|
      result[policy_type.slug.tr('-', '_')] = policies.current.where(policy_type_id: policy_type.id).count
    end
  end

  def line_item_changes(policies, time_range)
    LineItemChange.
      joins(line_item: :invoice).
      joins("inner join policy_quotes on (invoices.invoiceable_type = 'PolicyQuote' and invoices.invoiceable_id = policy_quotes.id)").
      where(
        created_at: time_range,
        analytics_category: %w[policy_premium master_policy_premium],
        policy_quotes: { policy_id: policies.ids }
      )
  end

  def premium_collected(line_item_changes)
    line_item_changes.inject(0) { |sum, com| sum + com.amount }
  end

  def commissions_collected(line_item_changes)
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

  def supported_filters(called_from_orders = false)
    @calling_supported_orders = called_from_orders
    {
      agency_id: [:scalar],
      policy_type_id: [:scalar],
      created_at: %i[interval scalar]
    }
  end

  def supported_orders
    supported_filters(true)
  end

  def default_pagination_per
    MAX_COUNTS
  end

  def maximum_pagination_per
    MAX_COUNTS
  end

  def filter_by_day?(start_date, end_date)
    (((end_date - 1.month) == start_date) || ((end_date - 1.week) == start_date)) || (end_date.mjd - start_date.mjd < 31)
  end

  def date_params
    if params[:filter].present?
      {
        start: params[:filter][:created_at][:start],
        end: params[:filter][:created_at][:end]
      }
    else
      params[:filter] = {}
      {
        start: @policies.order(:created_at).first&.created_at&.to_s || Time.now.beginning_of_year.to_s,
        end: Time.now.to_s
      }
    end
  end
end
