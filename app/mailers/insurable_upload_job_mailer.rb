class InsurableUploadJobMailer < ApplicationMailer
  def send_report(status:, message:, to:)
    @status = status
    @message = message

    mail(subject: 'Insurables Upload Report', to: to)
  end
end