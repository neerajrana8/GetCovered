class MasterPoliciesMailer < ApplicationMailer
  before_action { @staff = params[:staff] }
  before_action { @master_policy = params[:master_policy] }

  def bill_master_policy
    mail(to: @staff.email, subject: 'Master policy billing')
  end
end
