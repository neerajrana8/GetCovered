##
# V2 StaffAgency Accounts Controller
# File: app/controllers/v2/staff_agency/accounts_controller.rb

module V2
  module StaffAgency
    class AccountsController < StaffAgencyController
      
      before_action :set_account, only: %i[update show]
            
      def index
        if params[:short]
          super(:@accounts, current_staff.organizable.accounts)
        else
          super(:@accounts, current_staff.organizable.accounts, :agency)
        end
      end

      def account_policies
        account = Account.includes(:polices).find(params[:id])
        @account_policies = account.policies || []
        render "/v2/staff_agency/accounts/account_policies", status: :ok
      end
      
      def show
        render :show, status: :ok
      end
      
      def create
        if create_allowed?
          @account = current_staff.organizable.accounts.new(account_params)
          if @account.errors.none? && @account.save
            render :show, status: :created
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
            render :show, status: :ok
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
        super + '/accounts'
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
        permitted_params =
          params.require(:account).permit(
            :enabled, :staff_id, :title, :whitelabel, contact_info: {},
                                                      settings: {}, addresses_attributes: %i[
                                                        city country county id latitude longitude
                                                        plus_four state street_name street_number
                                                        street_two timezone zip_code
                                                      ]
          )
        existed_ids = permitted_params[:addresses_attributes]&.map { |addr| addr[:id] }

        unless existed_ids.nil? || existed_ids.compact.blank?
          (@account.addresses.pluck(:id) - existed_ids).each do |id|
            permitted_params[:addresses_attributes] <<
              ActionController::Parameters.new(id: id, _destroy: true).permit(:id, :_destroy)
          end
        end

        permitted_params
      end
        
      def supported_filters(called_from_orders = false)
        @calling_supported_orders = called_from_orders
        {
          id: %i[scalar array],
          agency: {
            title: %i[scalar like]
          },
          agency_id: %i[scalar array],
          owner: {
            profile: {
              contact_phone: %i[scalar like],
              contact_email: %i[scalar like]
            }
          },
          enabled: [:scalar],
          addresses: {
            state: %i[scalar array like],
            city: %i[scalar array like],
            zip_code: %i[scalar array]
          }
        }
      end

      def supported_orders
        supported_filters(true)
      end
    end
  end # module StaffAgency
end
