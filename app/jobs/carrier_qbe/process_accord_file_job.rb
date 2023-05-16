require 'fileutils'
require 'nokogiri'
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
            price = node.at_xpath('RentPolicyStatusRS/PersPolicy/CurrentTermAmt/Amt').content
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
          failed_policies << policy_number
          failed << node.to_xml
        end
      end
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
                  to: dylan@getcovered.io,
                  subject: "POLICY RENEWAL ERROR",
                  body: "#{ policy }\n\n#{ error.to_json }").deliver
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
