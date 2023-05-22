module EmailsHelper
  def masked_email(email)
    return unless email.present?

    email.gsub(/(?<=.).(?=[^@]*.@)/, '*')
  end
end
