# All policy related mailers here
class PolicyMailer < ApplicationMailer
  layout 'branded_mailer', only: 'notify_new_child_policy'

  def notify_new_child_policy
    @organization = params[:organization]
    @branding_profile = params[:branding_profile]
    @total_placement_cost = params[:total_placement_cost]
    @username = params[:user].profile.last_name
    @community = params[:community]
    @unit = params[:unit]
    mail(to: params[:user].contact_email,
         bcc: 'systememails@getcovered.io',
         from: 'policyverify@getcovered.io',
         subject: 'Master Policy Enrollment Confirmation')
  end

end
