require 'fileutils'
require 'nokogiri'
module CarrierQBE
  class FetchAccordFileJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      today = Time.current.to_date
      if [1, 2, 3, 4, 5].include?(today.wday)
        sftp = SFTPService.new((Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:url]).to_s,
                               (Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:login]).to_s,
                               password: Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:password])
        sftp.connect
        remote_files = sftp.list_files('/Outbound/')
        if remote_files.present?
          # TODO: maybe change the public folder to something else for security purposes?
          Dir.mkdir("#{Rails.root}/public/ftp_cp") unless File.exist?("#{Rails.root}/public/ftp_cp")

          remote_files.each do |file|
            next if CheckedFile.find_by(name: file)

            remote_file_path = "/Outbound/#{file}"
            file_path = "#{Rails.root}/public/ftp_cp/#{file}"
            # Need to download file for checksum GETCVR_DownloadTransOutput.xml
            sftp.download_file(remote_file_path, file_path)
            # Downloaded file's checksum
            checksum = Digest::SHA256.file(file_path).hexdigest

            # Check if the checksum exists in our DB
            if CheckedFile.find_by_checksum(checksum)
              # Search the same name file in DB, if does not exist then shoot an email
              unless CheckedFile.find_by(name: file, checksum: checksum)
                # UserMailer.already_exists(file, 'mailer check for code').deliver_now
                # Add this file to our records so that it doesn't deliver emails the next time it runs
                CheckedFile.create(name: file, checksum: checksum)
              end
            else
              # Extract date from the name of the file
              date_str = file.gsub(/\D/, '')
              # Set it as the uploaded date if parsed otherwise use the current date
              created_at = date_str.size == 8 ? DateTime.parse(date_str) : DateTime.now
              CheckedFile.create(name: file, checksum: checksum, created_at: created_at)
            end
            # We move files to processed folder so we don't keep downloading same files
            sftp.mkdir('/Processed') unless sftp.rename("/Outbound/#{file}", "/Processed/#{file}")
          end
        end
        sftp.disconnect
        CarrierQBE::ProcessAccordFileJob.perform_now
      end
    end
  end
end
