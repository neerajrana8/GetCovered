module V2
  module Public
    class SecretAuthenticationController < PublicController
      before_action :find_object

      def authenticate
        response.headers.merge!(@object.create_new_auth_token)
        head :ok
      end

      private

      def find_object
        decrypted_string = EncryptionService.decrypt(params[:secret_token])
        type, email = decrypted_string.split('/')
        @object = type.constantize&.find_by_email(email)
        if @object.nil?
          render(body: nil, status: :unprocessable_entity) && return
        end
      end
    end
  end
end
