require 'net/sftp'
require 'fileutils'
require 'nokogiri'

module Qbe
  module Acord
    # Qbe::Acord::Fetch service
    class Fetch < ApplicationService

      attr_accessor :remote_base_path
      attr_accessor :s3_base_path

      def initialize(remote_base_path, s3_base_path)
        @local_base_path = "#{ Rails.root }/tmp/acord/"
        @remote_base_path = remote_base_path
        @s3_base_path = s3_base_path
      end

      # Qbe::Acord::Fetch.call()
      # @param [<string>]
      # @param [<string>]
      # Loops through files stored on QBE SFTP server and creates Checksums for new
      # files that have no previously been parsed.
      def call
        if working_day?
          create_local_directory_if_does_not_exist()
          start_sftp_connection unless defined? @client
          get_remote_files unless defined? @remote_files

          if @remote_files.present?
            @remote_files.each do |file|
              next if CheckedFile.find_by(name: file)

              remote_file_path = "#{ @remote_base_path }#{ file }"
              local_file_path = "#{ @local_base_path }#{ file }"

              local_io = File.new(local_file_path)
              @client.download!(remote_file_path, local_io)
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
              # End the process by uploading the file to s3
              begin
                Utilities::S3Uploader.call(local_io, file, @s3_base_path, nil)
              rescue => e
                Rails.logger.debug(e)
              end
            end
          end
        end
      end

      private

      # working_day?()
      # @return [true, false]
      # Check if current day is Monday through Friday
      # QBE ACORD process is only available on week days
      def working_day?
        [1, 2, 3, 4, 5].include?(DateTime.current.wday)
      end

      # create_local_directory_if_does_not_exist()
      # @return [nil]
      # Creates local save directory for ACORD files if it does not already exist
      def create_local_directory_if_does_not_exist
        Dir.mkdir("#{Rails.root}/tmp/acord") unless Dir.exist?("#{Rails.root}/tmp/acord")
      end

      # start_sftp_connection()
      # @return [nil]
      # Starts a new sftp session with QBE server.  Maps connection to instance variable @client
      def start_sftp_connection
        session = Net::SSH.start(Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:url],
                                 Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:login],
                                 password: Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:password])
        @client = Net::SFTP::Session.new(session)
        @client.connect!
      end

      # get_remote_files()
      # @return [nil]
      # Maps files from remote server to @remote_files instance variable
      def get_remote_files
        @remote_files = Array.new
        @client.dir.foreach(@remote_base_path) do |entry|
          @remote_files << entry.name
        end
      end

    end
  end
end