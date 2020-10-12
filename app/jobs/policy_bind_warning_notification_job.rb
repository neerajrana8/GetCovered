class PolicyBindWarningNotificationJob < ApplicationJob
  queue_as :default

  def perform(message: )
    return if message.nil?
    emails = ['dev@getcoveredllc.com'] #, 'QBE-FPS-Production-Support.US-BOX@us.qbe.com', 'US-QBE-Renters-Support-Team@us.qbe.com']
	  ActionMailer::Base.mail(from: 'no-reply@getcoveredinsurance.com', to: emails, subject: "Get Covered Bind Warning", body: message).deliver
  end
end
