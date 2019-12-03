##
# V2 StaffAgency Accounts Controller
# File: app/controllers/v2/staff_agency/accounts_controller.rb

module V2
  module StaffAgency
    class AccountsController < StaffAgencyController
      
      before_action :set_account, only: [:update, :show]
            
      def index
        if params[:short]
          super(:@accounts, current_staff.organizable.accounts)
        else
          super(:@accounts, current_staff.organizable.accounts, :agency)
        end
      end
      
      def show
        render json: @account
      end
      
      def create
        if create_allowed?
          @account = current_staff.organizable.accounts.new(account_params)
          if !@account.errors.any? && @account.save
            render json: @account, status: :created
          else
            render json: @account.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      def update
        if update_allowed?
          if @account.update(account_params)
            render json: @account, status: :ok
          else
            render json: @account.errors, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: ['Unauthorized Access'] },
            status: :unauthorized
        end
      end
      
      
      private
      
        def view_path
          super + "/accounts"
        end
        
        def create_allowed?
          true
        end
        
        def update_allowed?
          true
        end
        
        def set_account
          @account = current_staff.organizable.accounts.find_by(id: params[:id])
        end
                        
        def account_params
          params.require(:account).permit(
            :enabled, :staff_id, :title, :whitelabel, contact_info: {},
            settings: {}, addresses_attributes: [
              :city, :country, :county, :id, :latitude, :longitude,
              :plus_four, :state, :street_name, :street_number,
              :street_two, :timezone, :zip_code
            ]
          )
        end
        
        def supported_filters(called_from_orders = false)
          @calling_supported_orders = called_from_orders
          {
            id: [ :scalar, :array ],
            agency: {
              title: [ :scalar, :like ],
            },
            agency_id: [ :scalar, :array ],
            owner: {
              profile: {
                contact_phone: [:scalar, :like],
                contact_email: [:scalar, :like]
              }
            },
            enabled: [ :scalar ],
            addresses: {
              state: [ :scalar, :array, :like ],
              city: [ :scalar, :array, :like ],
              zip_code: [ :scalar, :array ]
            }
          }
        end

        def supported_orders
          supported_filters(true)
        end
        
    end
  end # module StaffAgency
end
