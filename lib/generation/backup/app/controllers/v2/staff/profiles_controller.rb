# frozen_string_literal: true

module V2
  module Staff
    class ProfilesController < StaffController
      before_action :only_super_admins, except: [:show]
      before_action :set_profile, only: %i[show update destroy]

      def index
        @profiles = Profile.all
      end

      def show; end

      private

      def set_profile
        @profile = current_staff.profile
      end
    end
  end
end
