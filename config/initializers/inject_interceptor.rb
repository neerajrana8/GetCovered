ActiveSupport.on_load(:action_mailer) do
  ActionMailer::Base.register_interceptor(MailInterceptor)
end