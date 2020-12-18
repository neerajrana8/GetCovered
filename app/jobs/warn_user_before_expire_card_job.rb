class WarnUserBeforeExpireCardJob < ApplicationJob
  queue_as :default

  def perform(payment_profile)
    WarnUserBeforeExpireCardMailer.send_warn_expire_card(payment_profile).deliver
  end
end
