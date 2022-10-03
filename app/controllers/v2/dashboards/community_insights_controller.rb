# Community insights

module V2
  module Dashboards
    # Community insights controller
    class CommunityInsightsController < ApiController
      before_action :check_permissions

      CACHE_KEY = 'dashboards_ci'.freeze

      def stats
        date_from = DateTime.now - 5.year
        date_to = DateTime.now
        date_utc_format = '%Y-%m-%d %H:%M:%S'

        filter = {}
        filter = params[:filter] if params[:filter].present?

        cache_key = generate_cache_key(CACHE_KEY, filter)
        cache_key += "_#{current_staff.role}"

        stats = Rails.cache.read(cache_key)
        if stats.nil?
          if filter[:date]
            date_from_dt = Time.zone.parse(filter[:date][:from]) unless filter[:date][:from].nil?
            date_to_dt = Time.zone.parse(filter[:date][:to]) unless filter[:date][:to].nil?
            date_from = date_from_dt.utc.strftime(date_utc_format)
            date_to = date_to_dt.end_of_day.utc.strftime(date_utc_format)
          end

          units =
            if filter[:insurable_id].present?
              Insurable.where(insurable_id: filter[:insurable_id])
            else
              Insurable.where(insurable_type_id: InsurableType::UNITS_IDS)
            end

          accounts_ids = current_staff.organizable.accounts if current_staff.role == :agent.to_s
          accounts_ids = current_staff.organizable.id if current_staff.role == :staff.to_s
          units = units.where(account_id: accounts_ids) unless accounts_ids.nil?

          units_occupied_ids = units.where(occupied: true).pluck(:id)
          units_cx = units_occupied_ids.count
          policies =
            PolicyInsurable
              .joins(:policy)
              .where(insurable_id: units_occupied_ids)
              .where('policies.expiration_date > ?', Date.today)

          master_policies_for_units =
            policies
              .where(policies: { policy_type_id: PolicyType::MASTER_IDS })
              .pluck(:policy_id)

          master_policies_for_units_total = master_policies_for_units.count

          gc_policies_for_units = policies.where(policies: { agency_id: 1 }).pluck(:policy_id)
          gc_policies_for_units_total = gc_policies_for_units.count
          foreign_policies_for_units = policies.where(policies: { policy_in_system: false }).pluck(:policy_id)
          foreign_policies_for_units_total = foreign_policies_for_units.count

          policies_total = master_policies_for_units_total + gc_policies_for_units_total + foreign_policies_for_units_total

          units_all_ids = units.pluck(:id)
          claims_data = {}
          unless units_all_ids.count.zero?
            claims = Claim.by_created_at(date_from, date_to)
            claims = claims.where(insurable_id: units_all_ids)
            claims_amount_total = claims.sum(:amount)
            claims_approved_cx = claims.where(status: :approved).count
            claims_cx = claims.count

            claims_grouped = claims.group(:type_of_loss).count
            claims_by_status = claims.group(:status).count

            claim_stats = Claim.get_stats(date_from, date_to, units_all_ids)

            claims_data = {
              total: claims_cx,
              paid_amount: claims_amount_total,
              paid_percentage: (claims_approved_cx.to_f / claims_cx.to_f * 100.0).round(1),
              by_type_of_loss: claims_grouped,
              by_status: claims_by_status,
              by_type_of_loss_by_status_charts: claim_stats
            }
          end

          stats = {
            compliances: {
              totals: {
                units: units_cx,
                policies: policies_total,
                coverage: (policies_total.to_f / units_cx.to_f * 100.0).round(1)
              },
              master: {
                policies: master_policies_for_units_total,
                coverage: (master_policies_for_units_total.to_f / units_cx.to_f * 100.0).round(1)
              },
              gc: {
                policies: gc_policies_for_units_total,
                coverage: (gc_policies_for_units_total.to_f / units_cx.to_f * 100.0).round(1)
              },
              third_party: {
                policies: foreign_policies_for_units_total,
                coverage: (foreign_policies_for_units_total.to_f / units_cx.to_f * 100.0).round(1)
              }
            },
            claims: claims_data
          }
          Rails.cache.write(cache_key, stats, expires_in: 5.minutes)
        end

        render json: stats
      end

      private

      def check_permissions
        if current_staff && %(super_admin, staff, agent).include?(current_staff.role)
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end
    end
  end
end
