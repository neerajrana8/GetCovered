class WarnUserBeforeExpireCardMailerPreview < ActionMailer::Preview
  def send_warn_expire_card
    WarnUserBeforeExpireCardMailer.send_warn_expire_card(Invoice.last)

  end
end
