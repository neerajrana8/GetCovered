class MailInterceptor
  def self.delivering_email(message)
    # do not modify the message variable
    message.to.each do |f|
      user = User.find_by(email: f)
      
      next unless user

      body = if 'Finish Registering'.in?(message.subject) || 'Reset password instructions'.in?(message.subject) || 'Portal Invitation'.in?(message.subject)
        'This is sensitive information.'
      else
        message.body
      end
      contact_record = ContactRecord.new(
        direction: 'outgoing',
        approach: 'email',
        status: 'sent',
        contactable: user,
        body: body,
        subject: message.subject
      )
      contact_record.save
    end
  end
end
