# frozen_string_literal: true

# V1 Utility Controller
# file: app/controllers/v1/utility_controller.rb

module V1
  class UtilityController < V1Controller
    before_action :authenticate_super_admin!

    private

    def view_path
      super + '/utility'
    end
  end
end
