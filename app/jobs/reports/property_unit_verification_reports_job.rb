module Reports
  class PropertyUnitVerificationReportsJob < ApplicationJob
    queue_as :default

    def perform
      PropertyUnitVerificationCreate.run!
    end
  end
end
