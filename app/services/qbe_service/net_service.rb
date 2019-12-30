class QbeService
  class NetService
    def initialize
      @login = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:login]
      @password = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:password]
      @url = Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:url]
    end

    def upload(local_file_path, remote_file_path)
      connection do |sftp|
        sftp.upload!(local_file_path, remote_file_path) ? true : false
      end
    end

    def download(remote_file_path, local_file_path)
      connection do |sftp|
        sftp.download(remote_file_path, local_file_path)
      end
    end

    def read(remote_file_path)
      connection do |sftp|
        file = sftp.file.open(remote_file_path)
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
  end
end
