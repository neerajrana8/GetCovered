module Policies
  class List < ApplicationService
    FILTER_KEYS = %i[policy_in_system agency_id status account_id policy_type_id number].freeze
    PAGE = 1
    PER = 50

    def initialize(params, opts = {})
      @params = params
      @filters = {}
      @opts = opts
      @filters = @params[:filter] if @params[:filter].present?
    end

    def call
      fetch_policies
      call_filters
      call_pagination
      call_sorting
      @policies
    end

    private

    def fetch_policies
      @policies = Policy.filter(@filters.slice(*FILTER_KEYS))
        .includes(:account, :carrier, :agency, :policy_type, users: :profile)
        .references(:profiles)
        .includes(policy_quotes: { policy_application: :billing_strategy }, primary_user: %i[integration_profiles profile])
        .includes(primary_insurable: { insurable: :insurable }, insurables: [:agency, account: :agency])
    end

    def call_filters
      call_users_filter
      call_insurable_filter
    end

    def call_sorting
      return unless @params[:sort].present?

      @policies = @policies.order(updated_at: @params.dig(:sort, :updated_at)) if @params.dig(:sort, :updated_at).present?
      @policies = @policies.order(created_at: @params.dig(:sort, :created_at)) if @params.dig(:sort, :created_at).present?
    end

    def call_pagination
      return call_export_pagination if @opts[:export]

      page = @params.dig(:pagination, :page) || PAGE
      per = @params.dig(:pagination, :per) || PER
      @policies = @policies.order(created_at: :desc).page(page).per(per)
    end

    def call_export_pagination
      @policies = @policies.order(created_at: :desc)
    end

    def call_users_filter
      return unless @filters[:users].present?

      payload = @filters[:users]
      @policies = @policies.where('users.email LIKE ?', "%#{payload.dig(:email, :like)}%") if payload[:email].present?
      @policies = @policies.where('profiles.full_name LIKE ?', "%#{payload.dig(:profile, :full_name, :like)}%") if payload[:profile].present?
      @policies = @policies.where(users: { id: payload[:id] }) if payload[:id].present?
    end

    def call_insurable_filter
      return unless @filters[:insurable_id].present?

      @policies = @policies.where(policy_insurables: { insurable_id: @filters[:insurable_id] })
    end

    def call_tcode_filter
      return unless @filters[:tcode].present?

      matched_integrations = IntegrationProfile
        .where('external_id LIKE ? AND profileable_type = ?', "%#{@filters[:tcode]}%", 'User')
      matched_integrations_ids = matched_integrations.pluck(:profileable_id)
      policy_ids = PolicyUser.where(user_id: matched_integrations_ids, primary: true).pluck(:policy_id)
      @policies = @policies.where(id: policy_ids)
    end
  end
end
