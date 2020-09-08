module Insurables
  class UpdateCoveredStatusJob < ApplicationJob
    queue_as :default

    def perform
      Insurables::UpdateCoveredStatus.run!
    end
  end
end
