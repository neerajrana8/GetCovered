class StaffReportsMailer < ApplicationMailer
  before_action { @notifiable = params[:notifiable] }
  before_action { @report_path = params[:report_path] }
  after_action :record_mail

  def daily_purchase_activity
    attachments["DailyPurchaseActivity.csv"] = open(@report_path).read

    mail(:subject => "Daily Purchase Activity Report")
  end

  private

  def record_mail
    contact_record = ContactRecord.new(
      approach: 'email',
      direction: 'outgoing',
      status: 'sent',
      contactable: @notifiable
    )

    contact_record.save
  end
end
