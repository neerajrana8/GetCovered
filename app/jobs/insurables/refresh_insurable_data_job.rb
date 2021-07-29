module Insurables
  class RefreshInsurableDataJob < ApplicationJob
    queue_as :default

    def perform
      Insurable.all.each(&:refresh_insurable_data)
    end
  end
end
