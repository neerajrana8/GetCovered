class ApplicationMailer < ActionMailer::Base
  helper MailerHelper

  default from: 'info@getcoveredllc.com'
  layout 'mailer'
end
