module Insurables
  class RefreshInsurableDataJob < ApplicationJob
    queue_as :default

    def perform
      # Commenting out for now to prevent issues from popping up
      # Todo: Remove before 2023-02-1
      # Insurable.all.each(&:refresh_insurable_data)
    end
  end
end
