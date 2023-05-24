require 'net/sftp'
require 'fileutils'
require 'nokogiri'

module CarrierQBE
  class FetchAccordFileJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      if [1, 2, 3, 4, 5].include?(DateTime.current.wday)
        remote_path = Rails.env == 'production' ? 'Outbound/ACORD/' : 'Outbound/'
        Qbe::Acord::Fetch.call(remote_path)
        CarrierQBE::ProcessAccordFileJob.perform_now
      end
    end
  end
end
