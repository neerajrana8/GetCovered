##
# V2 Public Insurables Controller
# File: app/controllers/v2/public/insurables_controller.rb

module V2
  module Public
    class InsurablesController < PublicController
      include InsurablesMethods

      attr_reader :user_id, :community_id

      #TODO: need to provide method which will find community and all assigned info after redirect from email.
      # format of encoding in invitation email #EncryptionService.encrypt("user 1443 community 10035") "x2+vQO46KT4Dgc/T2XkN2s5Gyb/HZNWK6sPSRXEazr1Yb4o=--/nYMX6oHAPiVVaXW--IFLT6KwSsxJfHPRR8b5KdQ=="
      def insurable_by_auth_token
        decode_auth_params

        request.params[:id] = @community_id
        request.params[:user_id] = @user_id

        #render template: 'v2/public/insurables/show', status: :ok
        res = V2::Public::InsurablesController.dispatch(:show, request, response)
      end

      def additional_interest_name_usage
        if params[:community_id].blank?
          render json: standard_error(:insurable_id_param_blank,'insurable_id parameter can\'t be blank'),
                 status: :unprocessable_entity
        else
          @insurable = Insurable.find(params[:community_id])
          render template: 'v2/public/insurables/show', status: :ok
        end
      end

    end

  end # module Public
end
