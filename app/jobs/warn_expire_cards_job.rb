class WarnExpireCardsJob < ApplicationJob
  queue_as :default

  def perform
    time = Time.current
    payment_profiles = PaymentProfile.where('card @> ?', {exp_month: time.month, exp_year: time.year}.to_json)
    payment_profiles.find_each do |invoice|
      WarnUserBeforeExpireCardJob.perform_later(invoice)
    end
  end
end
