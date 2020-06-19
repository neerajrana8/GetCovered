##
# V2 StaffAgency Stripe Controller
# File: app/controllers/v2/staff_agency/stripe_controller.rb

module V2
  module StaffAgency
    class StripeController < StaffAgencyController
      before_action :is_owner?

      def stripe_button_link
        stripe_url = 'https://connect.stripe.com/express/oauth/authorize'
        redirect_uri = v2_agency_stripe_connect_url
        environment = ENV.fetch('RAILS_ENV', 'development')
        client_id = Rails.application.credentials.stripe[environment.to_sym]&.[](:client_id)
        
        render json: { stripe_url: "#{stripe_url}?redirect_uri=#{redirect_uri}&client_id=#{client_id}" }, status: 200
      end

      def connect
        # Send the authorization code to Stripe's API.
        code = params[:code]
        begin
          response = ::Stripe::OAuth.token({
            grant_type: 'authorization_code',
            code: code
          })
        rescue ::Stripe::OAuth::InvalidGrantError
          render json: { error: 'Invalid authorization code: ' + code }, status: 400 and return
        rescue ::Stripe::StripeError
          render json: { error: 'An unknown error occurred.' }, status: 500 and return
        end

        connected_account_id = response.stripe_user_id
        save_account_id(connected_account_id)

        # Render json.
        
        render json: { success: true }, status: 200
      end

      def save_account_id(connected_account_id)
        @agency.update_attribute(:stripe_id, connected_account_id)
      end

      def is_owner?
        render(json: { success: false, errors: ['Unauthorized Access'] }, 
               status: :unauthorized) and return unless current_staff.owner
      end
    end
  end
end
