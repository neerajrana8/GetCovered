module PoliciesDashboardMethods
  extend ActiveSupport::Concern

  MAX_COUNTS = 9998

  included do
    before_action :set_policies
  end

  def total
    apply_filters(:@filtered_policies, @policies)

    @total = {
      total_policies_sold: {
        bound: bound_policy_count(@filtered_policies),
        cancelled: cancelled_policy_count(@filtered_policies)
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
    @graphs[:graphs][date.to_s] = {
      total_new_policies: total_new_policies(policies),
      by_policy_type: by_policy_type(policies)
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

  def supported_filters(called_from_orders = false)
    @calling_supported_orders = called_from_orders
    {
      agency_id: [:scalar],
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
