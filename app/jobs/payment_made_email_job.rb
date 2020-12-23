class PaymentMadeEmailJob < ApplicationJob
  queue_as :default

  def perform(charge)
    PaymentMadeMailer.send_successful_payment_notification(charge).deliver
  end
end
