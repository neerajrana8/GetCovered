module MailerHelper
  def email_image_url(image)
    "#{Rails.configuration.email_images_url}/#{image}"
  end

  # 04/15/2022
  def formatted_date(date)
    date&.strftime("%m/%d/%Y")
  end
end
