# frozen_string_literal: true

module V1
  module Staff
    class DisputesController < StaffController
      before_action :set_dispute, only: [:show]

      def index
        super(:@disputes, @scope_association.disputes)
      end

      def show; end

      private

      def set_dispute
        @dispute = @scope_association.disputes.find(params[:id])
      end

      def view_path
        super + '/disputes'
      end
    end
  end
end
