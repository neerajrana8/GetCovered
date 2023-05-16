module EmailsHelper
  def masked_email(email)
    email.gsub(/(?<=.).(?=[^@]*.@)/, '*')
  end
end