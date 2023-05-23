require 'fileutils'
require 'nokogiri'
require 'csv'

module CarrierQBE
  class ProcessAccordFileJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      # Fetch Unprocessed Files
      files = CheckedFile.where(processed: false)
      files.each do |file|
        CarrierQBE::CreatePolicyJob.perform_now(file.name) unless Rails.env.production?
        file.update(processed: true) if process_accord_file(file.name)
      end
    end

    def process_accord_file(file_name)
      file_path = "#{Rails.root}/public/ftp_cp/#{file_name}"
      xml = File.open(file_path)
      doc = Nokogiri::XML(xml)
      node = doc.xpath('//ACORD//InsuranceSvcRs').first
      puts node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/LegalEntityCd').content
      failed = []
      failed_policies = []
      doc.xpath('//ACORD//InsuranceSvcRs').each do |node|
        transaction_type = node.at_xpath('RentPolicyStatusRS/TransactionType').content
        policy_number = node.at_xpath('RentPolicyStatusRS/PersPolicy/PolicyNumber').content
        if policy = Policy.find_by(number: policy_number)

          case transaction_type
          when 'C'
            reason = node.at_xpath('RentPolicyStatusRS/PersPolicy/QBE_BusinessSource').content
            cancel_policy(policy, reason)
          when 'R'
            reinstate_policy(policy)
          when 'E'
            price = node.at_xpath('RentPolicyStatusRS/PersPolicy/CurrentTermAmt/Amt').content
            endorsement(policy, price)
          when 'W'
            premium = node.at_xpath('RentPolicyStatusRS/PersPolicy/CurrentTermAmt/Amt').content
            begin
              PolicyRenewal::RenewalIssuer.call(policy, premium)
            rescue StandardError => e
              notify_renewal_failure(policy, e)
            rescue Exception => e
              notify_renewal_failure(policy, e)
            end
          else
            failed << node.to_xml
          end
        else
          add_to_failed_report(node)
          failed_policies << policy_number
          failed << node.to_xml
        end
      end
      send_failed_report()
      Dir.mkdir("#{Rails.root}/public/ftp_fail") unless File.exist?("#{Rails.root}/public/ftp_fail")
      failed_file = "#{Rails.root}/public/ftp_fail/#{file_name}"
      File.delete(failed_file) if File.exist?(failed_file)
      File.open(failed_file, 'w') do |f|
        f.write(failed)
      end


      begin
        file = File.open("#{Rails.root}/public/ftp_fail/#{file_name}")
        s3 = Aws::S3::Resource.new(region: 'us-west-2')
        bucket = Rails.application.credentials.aws[ENV['RAILS_ENV'].to_sym][:bucket]
        target = s3.bucket(bucket).object('accord/failed/' + file_name)
        target.upload_file(file)
      rescue => e
        Rails.logger.debug(e)
      end
      CarrierQBE::AccordFileMailer.failed_records(failed_policies).deliver_now
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

    def reinstate_policy(policy)
      # This will reinstate the policy
      policy.update(billing_status: 3)
    end

    def endorsement(policy, _price)
      policy.policy_premiums.last.policy_premium_items.where(category: 'premium', title: 'premium').order('created_at desc').first if policy.policy_premiums&.last&.policy_premium_items&.where(category: 'premium')
    end

    def notify_renewal_failure(policy, error)
      mailer.mail(from: "no-reply@getcoveredllc.com",
                  to: "dylan@getcovered.io",
                  subject: "POLICY RENEWAL ERROR",
                  body: "#{ policy }\n\n#{ error.to_json }").deliver
    end

    def send_failed_report
      if defined? @report
        @report_file_name = "duplicate-policies-#{ DateTime.current.strftime('%Y%m%d') }.csv"
        CSV.open(Rails.root.join('tmp',@report_file_name), "w") do |csv|
          @report.each do |row|
            csv << row
          end
        end

        mailer = ActionMailer::Base.new
        mailer.attachments[@report_file_name] = File.read("tmp/#{ @report_file_name }")
        mailer.mail(from: "no-reply@getcoveredllc.com",
                    to: 'QBE-FPS-Production-Support.US-BOX@us.qbe.com',
                    bcc: %w(dylan@getcovered.io hannah@getcovered.io mandy@getcovered.io brandon@getcovered.io),
                    subject: @report_file_name.gsub('-', ' ').gsub('.', ' ').titlecase,
                    body: "Duplicate Policy Report for #{ DateTime.current.strftime('%A, %B %e, %Y') }").deliver
      end
    end

    def create_failed_report()
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
      return @report
    end

    def add_to_failed_report(node)
      create_failed_report() unless defined? @report
      transaction_type = node.at_xpath('RentPolicyStatusRS/TransactionType').content
      transaction = transaction_type == 'W' ? 'Renewal' : 'New Business'
      duplicate_string_data = "#{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/PersonName/GivenName').content } #{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/NameInfo/PersonName/Surname').content } #{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/Addr1').content } #{ node.at_xpath('RentPolicyStatusRS/InsuredOrPrincipal/GeneralPartyInfo/Addr/Addr2').content }"
      puts duplicate_string_data
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

    # def renewal(policy_number)
    #   if PolicyRenewal::RenewalIssuer.call(policy_number)
    #     logger.info 'Success'
    #   else
    #     logger.info 'Failed'
    #   end
    # end
  end
end
