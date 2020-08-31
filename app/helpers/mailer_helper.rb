module MailerHelper
  def email_image_url(image)
    "#{Rails.configuration.email_images_url}/#{image}"
  end
end
