class RentGaranteeCancellationEmailJob < ApplicationJob
  queue_as :default

  def perform(policy)
    RentGaranteeCancellationMailer.send_cancellation_email(policy).deliver
  end
end
