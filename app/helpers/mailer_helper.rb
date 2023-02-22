module MailerHelper
  def email_image_url(image)
    "#{Rails.configuration.email_images_url}/#{image}"
  end

  def all_rights_reserved(from_date, to_date, text)
    rr_text = "©#{to_date.strftime('%Y')} #{text}"
    return rr_text unless from_date.present?

    "#{from_date} - #{rr_text}"
  end
end
