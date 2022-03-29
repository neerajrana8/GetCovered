module V2
  module StaffPolicySupport
    class CommunitiesController < StaffPolicySupportController
      before_action :set_substrate, only: [:index]

      def index
        if params[:short]
          super(:@insurables, Insurable)
        else
          super(:@insurables, Insurable, :addresses)
        end

        @insurables = @insurables.communities.where(preferred_ho4: true)
      end

      private

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Insurable)
        elsif !params[:substrate_association_provided]
          @substrate = @substrate.communities
        end
      end

      def view_path
        super + "/insurables"
      end

    end
  end
end
