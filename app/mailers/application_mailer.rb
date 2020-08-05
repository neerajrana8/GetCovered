class ApplicationMailer < ActionMailer::Base
  helper MailerHelper

  default from: 'from@example.com'
  layout 'mailer'
end
