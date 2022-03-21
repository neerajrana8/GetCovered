class PolicyBindWarningNotificationJob < ApplicationJob
  queue_as :default

  def perform(message: )
    return if message.nil?
    emails = ['bindwarning@getcovered.io']
	  ActionMailer::Base.mail(from: 'no-reply@getcoveredinsurance.com', to: emails, subject: I18n.t('policy_bind_warning_notification_job.get_covered_bind_warning'), body: message).deliver
  end
end
