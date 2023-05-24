require 'net/sftp'
require 'fileutils'
require 'nokogiri'

module CarrierQBE
  class FetchAccordFileJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      if [1, 2, 3, 4, 5].include?(DateTime.current.wday)
        Qbe::Acord::Fetch.call('Outbound/ACORD/', '/ACORD/')
        CarrierQBE::ProcessAccordFileJob.perform_now
      end
    end
  end
end
