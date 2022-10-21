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
        filepath = Rails.root.join('tmp', 'pex-rex', filename)

        event = Event.new(verb: 'post',
                          format: 'xml',
                          interface: 'SFTP',
                          status: 'in_progress',
                          process: 'qbe_pex_rex',
                          endpoint: Rails.application.credentials.qbe_sftp[:local][:url],
                          request: message,
                          eventable: Carrier.find(1))

        if event.save!

          FileUtils.mkdir_p(Rails.root.join('tmp','pex-rex')) unless File.directory?(Rails.root.join('tmp','pex-rex'))
          File.open(filepath, "w+") { |f| f.write(message) }

          event.started = Time.current
          sftp = SFTPService.new(Rails.application.credentials.qbe_sftp[:local][:url], Rails.application.credentials.qbe_sftp[:local][:login], password: Rails.application.credentials.qbe_sftp[:local][:password])
          sftp.connect

          upload = sftp.upload_file(filepath.to_s, "#{ Rails.application.credentials.qbe_sftp[:local][:workdir] }#{ filename }")

          if upload
            sftp.disconnect

            event.completed = Time.current
            event.status = "success"

            Policy.current.where(carrier_id: 1, policy_type_id: 1, billing_status: 'RESCINDED').find_each do |policy|
              policy.update billing_status: 'CURRENT'
            end

            if event.save!
              File.delete(filepath)
            end
          else
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