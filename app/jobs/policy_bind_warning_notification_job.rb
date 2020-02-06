class PolicyBindWarningNotificationJob < ApplicationJob
  queue_as :default

  def perform(message: )
    return if message.nil?
	  ActionMailer::Base.mail(from: 'no-reply@getcoveredinsurance.com', to: ['dev@getcoveredllc.com'], subject: "Get Covered Bind Warning", body: message).deliver
  end
end
