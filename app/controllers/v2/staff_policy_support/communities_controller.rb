module V2
  module StaffPolicySupport
    class CommunitiesController < StaffPolicySupportController
      before_action :set_substrate, only: [:index]

      def index
        if params[:short]
          super(:@insurables, @substrate, :insurables)
        else
          super(:@insurables, @substrate, :addresses)
        end
      end

      private

      def set_substrate
        super
        if @substrate.nil?
          @substrate = access_model(::Insurable).communities.where(preferred_ho4: true)
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
