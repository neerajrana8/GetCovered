##
# V1 Utility Agencies Controller
# file: app/controllers/v1/utility/agencies_controller.rb

module V1
  module Staff
    class AgenciesController < StaffController
      before_action :set_agency, only: [:show, :update], if: -> { current_staff.super_admin? }
      before_action :only_agents, only: [:show, :edit, :update]
      before_action :only_super_admins, only: [:index, :new, :create]

      def index
        super(:@agencies, ::Agency)
      end

      def show
      end

      def new
      end

      def create
        @agency = ::Agency.new(agency_params)
        if @agency.save
          render :show, status: :created
        else
          render json: @agency.errors, status: :unprocessable_entity
        end
      end

      def update
        @agency ||= @scope_association
        if @agency.update(agency_params)
          render :show, status: :ok
        else
          render json: @agency.errors, status: :unprocessable_entity
        end
      end

      private

        def view_path
          super + '/agencies'
        end

        def agency_params
          params.require(:agency)
                .permit(:title, :enabled, :agency_id,
                        contact_info: [:contact_phone,
                        :contact_phone_ext, :contact_email],
                        address_attributes: [
                          :id, :street_number, :street_one, 
                          :street_two, :locality, :county,
                          :region, :country, :postal_code, :plus_four
                        ])
        end

        def supported_filters
          {
            id: [ :scalar, :array ],
            title: [ :scalar, :array, :like ],
            enabled: [ :scalar ],
            tier: [ :scalar, :array ],
            contact_phone: [ :scalar ],
            contact_phone_ext: [ :scalar ],
            contact_email: [ :scalar, :array ]
          }
        end

        def set_agency
          @agency = ::Agency.find(params[:id])
        end
    end
  end
end
