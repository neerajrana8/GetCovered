require 'net/sftp'
require 'uri'

class SFTPService
  def initialize(host, user, password)
    @host = host
    @user = user
    @password = password
  end

  def connect
    sftp_client.connect!
  rescue Net::SSH::RuntimeError
    puts "Failed to connect to #{@host}"
  end

  def disconnect
    sftp_client.close_channel
    ssh_session.close
  end

  def upload_file(local_path, remote_path)
    @sftp_client.upload!(local_path, remote_path)do |event, uploader, *args|
      case event
      when :open then
        # args[0] : file metadata
        puts "starting upload: #{args[0].local} -> #{args[0].remote} (#{args[0].size} bytes}"
      when :put then
        # args[0] : file metadata
        # args[1] : byte offset in remote file
        # args[2] : data being written (as string)
        puts "writing #{args[2].length} bytes to #{args[0].remote} starting at #{args[1]}"
      when :close then
        # args[0] : file metadata
        puts "finished with #{args[0].remote}"
      when :mkdir then
        # args[0] : remote path name
        puts "creating directory #{args[0]}"
      when :finish
        puts "all done!"
      end
    end
  end

  def download_file(remote_path, local_path)
    @sftp_client.download!(remote_path, local_path)
  end

  def list_files(remote_path)
    files = Array.new
    @sftp_client.dir.foreach(remote_path) do |entry|
      files << entry.name
    end
    return files
  end

  def sftp_client
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  end

  private

  def ssh_session
    @ssh_session ||= Net::SSH.start(@host, @user, @password)
  end
end