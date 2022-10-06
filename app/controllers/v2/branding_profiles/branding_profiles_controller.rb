module V2
  # Branding profiles module
  module BrandingProfiles
    # Branding profiles controller
    class BrandingProfilesController < ApplicationController
      before_action :authenticate_staff!
      before_action :check_permissions

      # API endoint for dropdown filter list
      def filter
        per = 10
        page = 1

        # Permitted selection
        agencies_ids = current_staff.organizable.agencies.pluck(:id) if current_staff.role == :agent.to_s
        agencies_ids = [current_staff.organizable.agency_id] if current_staff.role == :staff.to_s
        agencies_ids << current_staff.organizable.id if current_staff.role == :agent.to_s

        # Prepareing filters by role
        if current_staff.role == 'staff' && !current_staff.getcovered_agent?
          if current_staff.organizable_type == 'Account'
            profileable_ids = [current_staff.organizable.id]
          end
        end

        if current_staff.organizable_type == 'Agency'
          current_agency = Agency.find(current_staff.organizable_id)
          # We are root agency
          if current_agency.agency_id.nil? && filter[:agency_id].blank?
            sub_agencies_ids = []
            sub_agencies = current_agency.agencies
            sub_agencies_ids = sub_agencies.pluck(:id) if sub_agencies.count.positive?
            sub_agencies_ids << current_staff.organizable_id
            profileable_ids = sub_agencies_ids
          end

          # filter[:agency_id] = [current_agency.id] unless current_agency.agency_id.nil?
          profileable_ids = [current_agency.id] unless current_agency.agency_id.nil?
        end

        profileable_type = current_staff.organizable_type

        unless profileable_type.nil?
          profiles = BrandingProfile.where(
            profileable_type: profileable_type,
            profileable_id: profileable_ids
          )
        end

        profiles = BrandingProfile.all if profileable_type.nil?
        if params[:filter].present?
          profiles = profiles.url_like(params[:filter][:url]) if params[:filter][:url].present?
        end

        # Sorting
        profiles = profiles.order(url: params[:sort].to_sym) if params[:sort].present?

        # Pagination
        if params[:pagination].present?
          page = params[:pagination][:page] if params[:pagination][:page]
          per = params[:pagination][:per] if params[:pagination][:per]
        end
        profiles = profiles.page(page).per(per)
        @branding_profiles = profiles
        render 'v2/branding_profiles/filter'
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
