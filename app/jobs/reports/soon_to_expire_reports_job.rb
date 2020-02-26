module Reports
  class SoonToExpireReportsJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      SoonToExpireCreate.run!
    end
  end
end
