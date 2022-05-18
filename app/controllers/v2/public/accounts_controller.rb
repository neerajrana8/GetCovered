
module V2
  module Public
    class AccountsController < PublicController

      def agency_accounts
        @accounts = Account.where(agency_id: params[:agency_id].to_i, enabled: true).order(:title)
        
        render json: (@accounts.map do |account|
          {
            id: account.id,
            title: account.title,
            address: [:street_number, :street_name, :street_two, :city, :state, :zip_code, :full].inject({}){|hash, prop| hash[prop] = account.primary_address&.send(prop); hash }
          }
        end), status: 200
        
      end

    end
  end
end
