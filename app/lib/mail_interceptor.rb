class MailInterceptor
  def self.delivering_email(message)
    # do not modify the message variable
    message.to.each do |f|
      user = User.find_by('email = ? or uid = ?', f, f)
      next unless user
      if 'Finish Registering'.in?(message.subject) || 'Reset password'.in?(message.subject) || 'Portal Invitation'.in?(message.subject)
        body = 'Sensitive information is hidden'
      else
        body = message.body
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
