module Reports
  class PropertyUnitVerificationReportsJob
    queue_as :default

    def perform
      PropertyUnitVerificationCreate.run!
    end
  end
end
