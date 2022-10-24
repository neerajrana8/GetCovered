require 'fileutils'

module CarrierQBE
  class GenerateAndSendCancellationListJob < ApplicationJob

    # Queue: Default
    queue_as :default

    def perform(*args)
      today = Time.current.to_date
      if [1,2,3,4,5].include?(today.wday)
        qbe_service = QbeService.new(:action => 'sendCancellationList')
        message = qbe_service.build_request

        filename = "pex-rex-#{ Rails.env }-#{ Time.current.strftime('%Y-%m-%d') }.xml"
        filepath = Rails.root.join('public', 'pex-rex', filename)
        remotepath = Rails.env == "production" ? "Inbound/#{ filename }" : "#{ filename }"

        puts "\nFILE CONFIG:\nFILE: #{ filename }\nPATH: #{ filepath }\nREMOTE: #{ remotepath }\n\n"

        event = Event.new(verb: 'post',
                          format: 'xml',
                          interface: 'SFTP',
                          status: 'in_progress',
                          process: 'qbe_pex_rex',
                          endpoint: Rails.application.credentials.qbe_sftp[:local][:url],
                          request: message,
                          eventable: Carrier.find(1))

        if event.save

          FileUtils.mkdir_p(Rails.root.join('public','pex-rex')) unless File.directory?(Rails.root.join('public','pex-rex'))
          File.open(filepath, "w+") { |f| f.write(message) }

          puts "\nFile write status: #{ File.exists?(filepath) }\n"

          event.started = Time.current
          sftp = SFTPService.new("#{ Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:url] }",
                                 "#{ Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:login] }",
                                 password: Rails.application.credentials.qbe_sftp[Rails.env.to_sym][:password])
          sftp.connect

          sftp.upload_file(filepath.to_s, remotepath)
          remote_files = sftp.list_files('/')
          upload_check = remote_files.include?(filename) ? true : false

          puts "\nUpload Check:\nRemote Files #{ remote_files.join(', ') }\nUpload Check: #{ upload_check }\n\n"

          if upload_check
            sftp.disconnect

            puts "\nUpload of #{ filename } has been completed.  Connection closed.\n\n"

            event.completed = Time.current
            event.status = "success"

            Policy.current.where(carrier_id: 1, policy_type_id: 1, billing_status: 'RESCINDED').find_each do |policy|
              policy.update billing_status: 'CURRENT'
            end

            if event.save
              File.delete(filepath)
            end
          else
            sftp.disconnect

            puts "\nUpload of #{ filename } has failed.  Connection closed.\n\n"

            event.update status: "error", completed: Time.current

            if Rails.env == "production"
              if ActionMailer::Base.mail(from: 'no-reply@getcovered.io',
                                         to: ['dylan@getcovered.io', 'jared@getcovered.io'],
                                         subject: "PEX/REX Backup Copy",
                                         body: message).deliver_now()
                Policy.current.where(carrier_id: 1, policy_type_id: 1, billing_status: 'RESCINDED').find_each do |policy|
                  policy.update billing_status: 'CURRENT'
                end
              end
            end
          end
        end
      end
    end

  end
end