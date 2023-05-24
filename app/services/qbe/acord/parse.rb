require 'open-uri'
require 'fileutils'
require 'nokogiri'

module Qbe
  module Acord
    # Qbe::Acord::Parse service
    class Parse < ApplicationService

      attr_accessor :checked_file_id
      attr_accessor :override_read

      def initialize(checked_file_id, override_read = false)
        @checked_file_id = checked_file_id
        @override_read = override_read
      end

      def call
        raise "CheckedFile ID null" if @checked_file_id.nil?
        raise "CheckedFile not found" unless set_checked_file()
        raise "CheckedFile previously read" if (@checked_file.processed && @override_read == false)
        build_s3_url()

        begin
          remote_document = URI.open(@s3_url)
        rescue Exception => error
          # Todo: Set up a failure notification
          Rails.logger.debug error
        else
          @checked_file.update processed: true if read_remote_document(remote_document)
        end
      end

      private

      # set_checked_file()
      # @return [true, false]
      def set_checked_file
        to_return = false
        if CheckedFile.exists?(id: @checked_file_id)
          @checked_file = CheckedFile.find(@checked_file_id)
          to_return = true
        end
        return to_return
      end

      def build_s3_url
        bucket = Rails.env == 'production' ? 'gc-public-prod' : 'gc-public-dev'
        url_array = ['https://', bucket, '.s3.', Rails.application.credentials.aws[Rails.env.to_sym][:region],
                     '.amazonaws.com/ACORD/', @checked_file.name]
        @s3_url = url_array.join('')
      end

      def read_remote_document(remote_document)
        process_status = false

        xml = Nokogiri::XML(remote_document)
        nodes = xml.xpath('//ACORD//InsuranceSvcRs')
        nodes.each do |node|
          transaction_type = node.at_xpath('RentPolicyStatusRS/TransactionType').content
          policy_number = node.at_xpath('RentPolicyStatusRS/PersPolicy/PolicyNumber').content

          if Policy.exists?(number: policy_number)
            policy = Policy.find_by_number(policy_number)
            check_premium = false

            case transaction_type
            when 'N' # TransactionType New Business
              check_premium = true
            when 'W' # TransactionType Renewal

            when 'P' # TransactionType Pending Cancellation

            when 'X' # TransactionType Rescind Cancellation

            when 'C' # TransactionType Cancellation
              cancellation_reason = node.at_xpath('RentPolicyStatusRS/PersPolicy/QBE_BusinessSource').content
              cancel_policy(policy, cancellation_reason)
            when 'R' # TransactionType Reinstatement
              # Todo: enable this
              check_premium = true
            when 'E' # TransactionType Endorsement
              check_premium = true
            when 'L' # TransactionType Claim Activity
              # Todo: add a claim counter?
              check_premium = true
            end

            if check_premium
              recorded_premium = node.at_xpath('RentPolicyStatusRS/PersPolicy/CurrentTermAmt/Amt').content
            end
          else
            add_to_duplicate_report(node)
          end
        end

        if defined? @duplicate_report
          puts @duplicate_report.length
          Qbe::Acord::DuplicateReport.call(@duplicate_report) if @duplicate_report.length > 0
        end

        return process_status
      end

      def cancel_policy(policy, reason)
        reason_map = {
          'AP' => 'nonpayment',
          'AR' => 'agent_request',
          'IR' => 'insured_request',
          'NP' => 'new_application_nonpayment',
          'UW' => 'underwriter_cancellation'
        }
        policy.cancel(reason_map[reason])
      end

      def create_duplicate_report()
        @duplicate_report = Array.new
      end

      def add_to_duplicate_report(node)
        create_duplicate_report unless defined? @duplicate_report
        @duplicate_report << node
      end
    end
  end
end
