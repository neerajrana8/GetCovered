class WarnUserBeforeExpireCardMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_warn_expire_card(payment_profile)
    @user = payment_profile.payer
    if @user.is_a? User
      @agency = Agency.first
      @branding_profile = @agency.branding_profiles.first
      mail(from: 'support@' + @branding_profile.url, to: @user.email, subject: "#{@agency.title} - Credit Card Expiring")
    end
  end
end
