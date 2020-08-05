class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'

  def email_image_url(image)
    "#{Rails.configuration.email_images_url}/#{image}"
  end
end
