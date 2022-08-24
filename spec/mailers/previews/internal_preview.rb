# Preview all emails at http://localhost:3000/rails/mailers/internal
class InternalPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/internal/error
  def error
    InternalMailer.error
  end

end
