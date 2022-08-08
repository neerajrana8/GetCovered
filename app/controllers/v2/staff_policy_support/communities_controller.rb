module V2
  module StaffPolicySupport
    class CommunitiesController < StaffPolicySupportController
      DEFAULT_LIMIT = 50

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
        begin
          if params[:search].blank?
            @substrate = @substrate.limit(DEFAULT_LIMIT)
          else
            title = Insurable.arel_table[:title]
            @substrate = @substrate.where(title.matches("%#{params[:search]}%"))
          end
        rescue StandardError => e
          render json: standard_error(:query_failed,"#{e.message}"),
                 status: :unprocessable_entity
        end
      end

      def view_path
        super + "/insurables"
      end

    end
  end
end
