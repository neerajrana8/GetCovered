class DailySalesReportMailer < ApplicationMailer
  layout 'agency_styled_mail'

  def send_report(recipients, report_path, partner, date)
    @partner = partner
    @date = date
    @branding_profile = BrandingProfile.global_default

    attachments["Daily Sales Report - #{partner} - Renters Insurance - #{date}.csv"] = open(report_path).read

    mail(subject: "Get Covered Daily Sales Report - #{partner} - Renters Insurance - #{date}", to: recipients)
  end
end
