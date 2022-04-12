module PoliciesDashboardMethods
  extend ActiveSupport::Concern

  included do
    before_action :set_policies
  end

  def total
    # lics = line_item_changes(all_policies, date_params[:start]...date_params[:end])
    # total_premium_paid = premium_collected(lics)
    # bound_policies = bound_policy_count(all_policies)
    # filtered_policies_count = all_policies.count
    #
    # @total = {
    #   all_policies_count: filtered_policies_count,
    #   bound: bound_policies,
    #   cancelled: cancelled_policy_count(all_policies),
    #   total_premium_paid: total_premium_paid,
    #   average_premium_paid: filtered_policies_count.zero? ? 0 : (total_premium_paid.to_f / filtered_policies_count).round,
    #   agencies_commissions: commissions_collected(lics, recipient_type: 'Agency'),
    #   get_covered_commissions: commissions_collected(lics, recipient_type: 'Agency', recipient_id: Agency::GET_COVERED_ID),
    #   carriers_commissions: commissions_collected(lics, recipient_type: 'Carrier')
    # }
    #
    # render json: @total.to_json
    render json: {
      message: "Currently Unavailable: Under Construction"
    }, status: :ok
  end

  def graphs
    # start_date = Date.parse(date_params[:start])
    # end_date   = Date.parse(date_params[:end])
    #
    # @graphs = {
    #   total: {
    #     total_new_policies: 0,
    #     current_added_policies: 0,
    #     premium_collected: 0,
    #     agencies_commissions: 0,
    #     get_covered_commissions: 0,
    #     carriers_commissions: 0
    #   },
    #   graphs: {}
    # }
    #
    # if filter_by_day?(start_date, end_date)
    #   start_date.upto(end_date) do |date|
    #     params[:filter][:created_at] = Date.parse(date.to_s).all_day
    #     apply_filters(:@policies_by_day, @policies)
    #     set_day_data(@policies_by_day, date)
    #   end
    # else
    #   while start_date < end_date
    #     params[:filter][:created_at] = start_date.all_month
    #     apply_filters(:@policies_by_month, @policies)
    #     set_day_data(@policies_by_month, start_date.end_of_month)
    #     start_date += 1.month
    #   end
    # end
    #
    # render json: @graphs.to_json
    render json: {
      message: "Currently Unavailable: Under Construction"
    }, status: :ok
  end

  private

  def set_policies
    @policies = all_policies
  end

  def all_policies
    if params[:filter][:policy_type_id].present?
      Policy.not_master.where(policy_type_id: params[:filter][:policy_type_id])
    else
      Policy.not_master
    end
  end

  def set_day_data(policies, date)
    lics = line_item_changes(all_policies, params[:filter][:created_at])
    @graphs[:graphs][date.to_s] = {
      total_new_policies: total_new_policies(policies),
      current_added_policies: policies.current.count,
      premium_collected: premium_collected(lics),
      agencies_commissions: commissions_collected(lics, recipient_type: 'Agency'),
      get_covered_commissions: commissions_collected(lics, recipient_type: 'Agency', recipient_id: Agency::GET_COVERED_ID),
      carriers_commissions: commissions_collected(lics, recipient_type: 'Carrier')
    }

    @graphs[:total] = {
      total_new_policies: @graphs[:total][:total_new_policies] += @graphs[:graphs][date.to_s][:total_new_policies],
      current_added_policies: @graphs[:total][:current_added_policies] += @graphs[:graphs][date.to_s][:current_added_policies],
      premium_collected: @graphs[:total][:premium_collected] += @graphs[:graphs][date.to_s][:premium_collected],
      agencies_commissions: @graphs[:total][:agencies_commissions] += @graphs[:graphs][date.to_s][:agencies_commissions],
      get_covered_commissions: @graphs[:total][:get_covered_commissions] += @graphs[:graphs][date.to_s][:get_covered_commissions],
      carriers_commissions: @graphs[:total][:carriers_commissions] += @graphs[:graphs][date.to_s][:carriers_commissions]
    }
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

  # policies - ActiveRecord::Relation
  def line_item_changes(policies, time_range)
    LineItemChange.
      joins(line_item: :invoice).
      joins("inner join policy_quotes on (invoices.invoiceable_type = 'PolicyQuote' and invoices.invoiceable_id = policy_quotes.id)").
      where(
        created_at: time_range,
        field_changed: :total_received,
        analytics_category: %w[policy_premium master_policy_premium]
      ).
      where("policy_quotes.policy_id IN (#{policies.select(:id).to_sql})")
  end

  def premium_collected(line_item_changes)
    line_item_changes.inject(0) { |sum, com| sum + com.amount }
  end

  def commissions_collected(line_item_changes, recipient)
    CommissionItem.
      references(:commissions).
      includes(:commission).
      where(
        reason: line_item_changes,
        analytics_category: %w[policy_premium master_policy_premium],
        commissions: recipient
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
        end: Time.zone.now.to_s
      }
    end
  end
end
