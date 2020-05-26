##
# V2 StaffAccount Stripe Controller
# File: app/controllers/v2/staff_account/stripe_controller.rb

module V2
  module StaffAccount
    class PlaidController < StaffAccountController
      
      def connect
        environment = case ENV['RAILS_ENV']
                      when 'development'
                        :sandbox
                      when 'awsdev'
                        :sandbox
                      when 'test'
                        :sandbox
                      when 'aws_staging'
                        :development
                      when 'production'
                        :production
                      else
                        :sandbox
          end
        client = ::Plaid::Client.new(env: environment,
                                     client_id: Rails.application.credentials.plaid[:client_id],
                                     secret: Rails.application.credentials.plaid[ENV['RAILS_ENV'].to_sym]&.[](:secret_key),
                                     public_key: Rails.application.credentials.plaid[:public_key])
          
        exchange_token_response = client.item.public_token.exchange(params[:plaid_public_token])
        access_token = exchange_token_response['access_token']
        
        stripe_response = client.processor.stripe.bank_account_token.create(access_token, params[:account_id])
        payment_profile = current_staff.organizable.payment_profiles.new(
          source_id: stripe_response['stripe_bank_account_token'], 
          source_type: 'bank_account'
        )
        if payment_profile.save
          render json: { success: true }, status: 200
        else
          render json: { errors: payment_profile.errors }, status: :unprocessable_entity
        end
      rescue Plaid::InvalidInputError => e
        render json: { error: e.error_message }, status: :unprocessable_entity
      end
    end
  end
end
