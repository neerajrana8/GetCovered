class StaffReportsMailer < ApplicationMailer
  before_action { @notifiable = params[:notifiable] }
  before_action { @report_path = params[:report_path] }

  def daily_purchase_activity
    attachments["DailyPurchaseActivity.csv"] = open(@report_path).read

    mail(:subject => "Daily Purchase Activity Report")
  end

end
