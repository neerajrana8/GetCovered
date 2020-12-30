class RentGuaranteeCancellationEmailJob < ApplicationJob
  queue_as :default

  def perform(policy)
    RentGuaranteeCancellationMailer.send_cancellation_email(policy).deliver
  end
end
