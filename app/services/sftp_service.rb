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
    @sftp_client.upload!("#{ Rails.root.to_s }/#{ local_path }", remote_path)
    puts "Uploaded #{local_path}"
  end

  def download_file(remote_path, local_path)
    @sftp_client.download!(remote_path, local_path)
    puts "Downloaded #{remote_path}"
  end

  def list_files(remote_path)
    @sftp_client.dir.foreach(remote_path) do |entry|
      puts entry.longname
    end
  end

  def sftp_client
    @sftp_client ||= Net::SFTP::Session.new(ssh_session)
  end

  private

  def ssh_session
    @ssh_session ||= Net::SSH.start(@host, @user, @password)
  end
end