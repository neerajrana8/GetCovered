require 'net/sftp'
require 'fileutils'
require 'nokogiri'
module CarrierQBE
  class FetchAccordFileJob < ApplicationJob
    # Queue: Default
    queue_as :default

    def perform
      today = Time.current.to_date
      if [1, 2, 3, 4, 5].include?(today.wday)
        ssh_session = Net::SSH.start(Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:url],
                                     Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:login],
                                     password: Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:password])
        client = Net::SFTP::Session.new(ssh_session)
        client.connect!

        remote_base_path = 'Outbound/ACORD/'
        remote_files = Array.new
        client.dir.foreach(remote_base_path) do |entry|
          remote_files << entry.name
        end

        if remote_files.present?
          # TODO: maybe change the public folder to something else for security purposes?
          Dir.mkdir("#{Rails.root}/tmp/acord") unless File.exist?("#{Rails.root}/tmp/acord")

          remote_files.each do |file|
            next if CheckedFile.find_by(name: file)

            remote_file_path = "#{remote_base_path}#{file}"
            local_file_path = "#{Rails.root}/tmp/acord/#{file}"

            local_io = File.new(local_file_path, mode: 'wb')
            client.download!(remote_file_path, local_io)
            local_io.close

            # Need to download file for checksum GETCVR_DownloadTransOutput.xml
            # downloaded_file = sftp.download_file(remote_file_path, file_path)
            # Downloaded file's checksum
            checksum = Digest::SHA256.file(local_file_path).hexdigest

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
            client.mkdir('/Processed') unless client.rename("/Outbound/ACORD/#{file}", "/Processed/ACORD/#{file}")
            begin
              Utilities::S3Uploader.call(local_io, file, '/ACORD/', nil)
            rescue => e
              Rails.logger.debug(e)
            end
          end
        end
        client.disconnect
        CarrierQBE::ProcessAccordFileJob.perform_now
      end
    end
  end
end
