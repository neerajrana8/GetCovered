module CarrierQbe
  class ProcessExternalMasterPolicyUploadJob < ApplicationJob
    require 'csv'
    require 'open-uri'

    queue_as :default

    def perform(config = nil)
      unless config.nil?
        URI.open(config[:document]).each do |row|
          data = row.split(',')
          CarrierQbe::SendExternalMasterPolicyEoiJob.perform_later(data, config)
        end
      end
    end

  end
end

