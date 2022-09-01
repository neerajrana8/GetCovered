class MailObserver
  def self.delivered_email(message)
    message.to.each do |f|
      user = User.find_by(email: f)
      if user
        contact_record = ContactRecord.new(
          direction: 'outgoing',
          approach: 'email',
          status: 'sent',
          contactable: user,
          body: message.body,
          subject: message.subject
        )
        contact_record.save
      end
    end
  end
end
