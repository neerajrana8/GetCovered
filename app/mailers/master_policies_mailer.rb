class MasterPoliciesMailer < ApplicationMailer
  before_action do
    @staff = params[:staff]
    @master_policy = params[:master_policy]
    @invoice = params[:invoice]
  end

  def bill_master_policy
    mail(to: @staff.email, subject: 'Master policy billing')
  end
end
