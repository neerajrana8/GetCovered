class PolicyBindWarningNotificationJob < ApplicationJob
  queue_as :default

  def perform(message: )
    return if message.nil?
    notification_email = ENV["RAILS_ENV"] == "production" ? "bindwarning@getcovered.io" : "dev@getcoveredllc.com"
	  ActionMailer::Base.mail(from: 'no-reply@getcoveredinsurance.com', to: notification_email, bcc: "systememails@getcovered.io", subject: I18n.t('policy_bind_warning_notification_job.get_covered_bind_warning'), body: message).deliver
  end
end
