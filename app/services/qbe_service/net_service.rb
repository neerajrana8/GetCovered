class QbeService
  class NetService
    attr_reader :working_directory

    def initialize
      @login = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:login]
      @password = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:password]
      @url = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:url]
      @working_directory = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:workdir]
    end

    def upload(local_file_path)
      connection do |sftp|
        full_local_path = File.expand_path(local_file_path)
        full_path = full_remote_path(File.basename(local_file_path))
        sftp.upload!(full_local_path, full_path) ? true : false
      end
    end

    def download(remote_file_path, local_file_path)
      connection do |sftp|
        sftp.download(full_remote_path(remote_file_path), local_file_path)
      end
    end

    def read(remote_file_path)
      connection do |sftp|
        file = sftp.file.open(full_remote_path(remote_file_path))
        return file.read
      end
    end

    private

    # this realisation closes connection after finishing operations inside (as opposed to
    # sftp = Net::SFTP.start(@url, @login, password: @password) )
    def connection
      Net::SFTP.start(@url, @login, password: @password) do |sftp|
        yield sftp
      end
    end

    def full_remote_path(relative_remote_path)
      "#{working_directory}/#{relative_remote_path}"
    end
  end
end
