module Reports
  class ThirdPartySoonToExpireReportsJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      ThirdPartySoonToExpireCreate.run!
    end
  end
end
