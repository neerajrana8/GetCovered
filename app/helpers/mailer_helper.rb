module MailerHelper
  def email_image_url(image)
    "#{Rails.configuration.email_images_url}/#{image}"
  end

  def all_rights_reserved(from_date, to_date, text)
    if from_date.present?
      "#{from_date} - ©#{to_date} #{text}"
    else
      "©#{to_date.strftime('%Y')} #{text}"
    end
  end
end
