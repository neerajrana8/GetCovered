##
# V2 SDK Controller
# File: app/controllers/v2/sdk_controller.rb

module V2
  class SdkController < V2Controller
    before_action :verify_auth_token

    private

    def verify_auth_token
      if request.key? :authorization
        render_unathorized()
      else
        @auth = AccessToken.verify(request.headers[:authorization])
        if @auth == false
          render_unathorized()
        else
          set_bearer()
        end
      end
    end

    def render_unathorized
      render json: standard_error(:unathorized, "401 access Unathorized", {}),
             status: :unauthorized
    end

    def set_bearer
      @bearer = @auth.bearer
    end

  end
end
