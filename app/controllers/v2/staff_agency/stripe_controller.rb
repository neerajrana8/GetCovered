##
# V2 StaffAgency Stripe Controller
# File: app/controllers/v2/staff_agency/stripe_controller.rb

module V2
  module StaffAgency
    class StripeController < StaffAgencyController

      def stripe_button_link
        stripe_url = 'https://connect.stripe.com/express/oauth/authorize'
        redirect_uri = v2_agency_stripe_connect_url
        client_id = Rails.application.credentials.stripe&.[](:client_id)
        
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
        current_staff.organizable.update_attribute(:stripe_id, connected_account_id)
      end

    end
  end
end
