# frozen_string_literal: true

# V1 User Controller
# file: app/controllers/v1/user_controller.rb

module V1
  class UserController < V1Controller
    before_action :authenticate_user!

    private

    def view_path
      super + '/user'
    end
  end
end
