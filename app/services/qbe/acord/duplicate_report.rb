require 'fileutils'
require 'nokogiri'
require 'csv'

module Qbe
  module Acord
    # Qbe::Acord::DuplicateReport service
    class DuplicateReport < ApplicationService

      attr_accessor :duplicate_report

      def initialize(duplicate_report)
        @duplicate_report = duplicate_report
      end

      def call
        @duplicate_report.each do |node|
          add_to_report(node)
        end
        save_report()
      end

      private

      def create_report
        headers = [
          'Latest_Policy_PROCESS_DATE', # 0
          'DupItems', # 1
          'QUOTE_AND_POLICY_NUMBER', # 2
          'Policy_Status', # 3
          'CANCEL_REASON', # 4
          'ORIG_EFF_DATE', # 5
          'EFFECTIVE_DATE', # 6
          'EXPIRATION_DATE', # 7
          'CANCEL_DATE', # 8
          'CLIENT_NUMBER', # 9
          'FIRST_NAME', # 10
          'LAST_NAME', # 11
          'ADDRESS_LINE', # 12
          'ADDRESS_LINE_2', # 13
          'CITY', # 14
          'STATE_CODE', # 15
          'ZIP_CODE', # 16
          'PROCESS_DATE', # 17
          'Dup_Count', # 18
          'NBR_Of_Claim', # 19
          'AGENT_NUMBER', # 20
          'DOWNLOAD_STATUS', # 21
          'Mod.', # 22
          'USER_ID', # 23
          'PAPERLESS_FLAG', # 24
          'DAYTIME_TELEPHONE_NUMBER', # 25
          'EVENING_TELEPHONE_NUMBER', # 26
          'DAYTIME_CELLULAR_PHONE', # 27
          'DAYTIME_E_MAIL', # 28
          'EVENING_E_MAIL', # 29
          'MrktInfo_EMAIL_ADDRESS', # 30
          'TOTAL_PREM', # 31
          'LatestTransaction', # 32
          'Notes' # 33
        ]
        @report = Array.new
        @report << headers
      end

      def add_to_report(node)
        create_report() unless defined? @report
        transaction_type = node.at_xpath('RentPolicyStatusRS/TransactionType').content
        transaction = transaction_type == 'W' ? 'Renewal' : 'New Business'
        duplicate_string_data = "#{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/PersonName/GivenName').content } #{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/PersonName/Surname').content } #{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/Addr1').content } #{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/Addr2').content }"
        row = [
          DateTime.current.strftime('%m/%d/%Y'), # 0
          duplicate_string_data, # 1
          node.at_xpath('RentPolicyStatusRS/PersPolicy/PolicyNumber').content, # 2
          'Active', # 3
          nil, # 4
          node.at_xpath('RentPolicyStatusRS/PersPolicy/ContractTerm/EffectiveDt').content, # 5
          node.at_xpath('RentPolicyStatusRS/PersPolicy/ContractTerm/EffectiveDt').content, # 6
          node.at_xpath('RentPolicyStatusRS/PersPolicy/ContractTerm/ExpirationDt').content, # 7
          '1/1/2000', # 8
          nil, # 9
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/PersonName/GivenName').content, # 10
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/PersonName/Surname').content, # 11
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/Addr1').content, # 12
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/Addr2').content, # 13
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/City').content, # 14
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/StateProvCd').content, # 15
          node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/PostalCode').content, # 16
          DateTime.current.strftime('%m/%d/%Y'), # 17
          nil, # 18
          '0', # 19
          'GETCVR', # 20
          'NOT SUBMITTED', # 21 ???
          nil, # 22 ???
          'QBE_RTRB1', # 23
          'F', # 24
          nil, # 25
          nil, # 26
          nil, # 27
          nil, # 28
          nil, # 29
          nil, # 30
          node.at_xpath('RentPolicyStatusRS/PersPolicy/CurrentTermAmt/Amt').content, # 31
          transaction, # 32
          "Cancel Eff. #{ node.at_xpath('RentPolicyStatusRS/PersPolicy/ContractTerm/EffectiveDt').content }"
        ]
        @report << row
      end

      # create_local_directory_if_does_not_exist()
      # @return [nil]
      # Creates local save directory for ACORD files if it does not already exist
      def create_local_directory_if_does_not_exist
        Dir.mkdir("#{Rails.root}/tmp/duplicates") unless File.exist?("#{Rails.root}/tmp/duplicates")
      end

      def save_report
        create_local_directory_if_does_not_exist()
        file_name = "duplicate-policies.#{ DateTime.current.strftime('%Y%m%d%H%I%S') }.csv"
        local_path = "#{Rails.root}/tmp/duplicates/#{ file_name }"
        CSV.open(local_path, "wb") do |csv|
          @report.each do |row|
            csv << row
          end
        end

        begin
          upload = Utilities::S3Uploader.call(File.open(local_path), file_name, '/duplicate-report/', nil)
        rescue Exception => e
          # Todo: Need to do something useful with this error
        else
          # Todo: need to fix generated csv
          # CarrierQBE::DuplicatePoliciesMailer.notify(upload, file_name).deliver
        end
      end

    end
  end
end
