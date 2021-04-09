##
# V2 SDK Controller
# File: app/controllers/v2/sdk_controller.rb

module V2
  class SdkController < V2Controller
    before_action :verify_auth_token
    after_action :capture_response

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
          set_event()
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

    def set_event
      @event = @auth.events.create(
          verb: request.method().downcase,
          process: request.fullpath().sub('/','').gsub("/","-"),
          endpoint: request.original_url,
          request: request.body,
          started: Time.current
      )
    end

    def capture_response
      @event.update(
          response: response.body,
          completed: Time.current,
          status: response.message == 'OK' ? 'success' : 'error'
      )
    end

  end
end
