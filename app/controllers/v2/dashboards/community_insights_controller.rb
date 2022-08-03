# Community insights

module V2
  module Dashboards
    # Community insights controller
    class CommunityInsightsController < ApplicationController
      before_action :check_permissions

      def stats
        @data = {}
        date_from = DateTime.now - 5.year
        date_to = DateTime.now

        filter = {}
        filter = params[:filter] if params[:filter].present?

        if filter[:date]
          date_from_dt = Time.zone.parse(filter[:date][:from]) unless filter[:date][:from].nil?
          date_to_dt = Time.zone.parse(filter[:date][:to]) unless filter[:date][:to].nil?
          date_from = date_from_dt.utc.strftime(date_utc_format)
          date_to = date_to_dt.end_of_day.utc.strftime(date_utc_format)
        end

        if filter[:insurable_id].present?
          units = Insurable.where(insurable_id: filter[:insurable_id], occupied: true).pluck(:id) if filter[:insurable_id].present?
        else
          units = Insurable.where(occupied: true).pluck(:id)
        end

        units_cx = units.count
        policies = PolicyInsurable.joins(:policy).where(insurable_id: units).where('policies.expiration_date > ?', Date.today)

        master_policies_for_units = policies.where(policies: { policy_type_id: PolicyType::MASTER_IDS })
                                      .pluck(:policy_id)

        master_policies_for_units_total = master_policies_for_units.count

        gc_policies_for_units = policies.where(policies: { agency_id: 1 }).pluck(:policy_id)
        gc_policies_for_units_total = gc_policies_for_units.count
        foreign_policies_for_units = policies.where(policies: { policy_in_system: false }).pluck(:policy_id)
        foreign_policies_for_units_total = foreign_policies_for_units.count

        policies_total = master_policies_for_units_total + gc_policies_for_units_total + foreign_policies_for_units_total

        claims = Claim.where(insurable_id: units).by_created_at(date_from, date_to)
        claims_amount_total = claims.sum(:amount)
        claims_approved_cx = claims.where(status: :approved).count
        claims_cx = claims.count

        claims_grouped = claims.group(:type_of_loss).count
        claims_by_status = claims.group(:status).count

        claim_stats = Claim.get_stats(date_from, date_to, units)

        @claims_data = {
          total: claims_cx,
          paid_amount: claims_amount_total,
          paid_percentage: ((claims_approved_cx.to_f / claims_cx.to_f) * 100).round(2),
          by_type_of_loss: claims_grouped,
          by_status: claims_by_status,
          by_type_of_loss_by_status_charts: claim_stats
        }

        @data = {
          compliances: {
            totals: {
              units: units_cx,
              policies: policies_total,
              coverage: ((policies_total.to_f / units_cx.to_f) * 100).round(2)
            },
            master: {
              policies: master_policies_for_units_total,
              coverage: ((master_policies_for_units_total.to_f / units_cx.to_f) * 100).round(2)
            },
            gc: {
              policies: gc_policies_for_units_total,
              coverage: ((gc_policies_for_units_total.to_f / units_cx.to_f) * 100).round(2)
            },
            third_party: {
              policies: foreign_policies_for_units_total,
              coverage: ((foreign_policies_for_units_total.to_f / units_cx.to_f) * 100).round(2)
            }
          },
          claims: @claims_data
        }

        render json: @data
      end

      private

      def check_permissions
        if current_staff && current_staff.role == :super_admin
          true
        else
          render json: { error: 'Permission denied' }, status: 403
        end
      end
    end
  end
end
