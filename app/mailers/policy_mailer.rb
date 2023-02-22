class PolicyMailer < ApplicationMailer
  layout 'branded_mailer'
  def coverage_proof_uploaded
    @policy = params[:policy]
    @agency = @policy.agency
    @branding_profile = @policy.branding_profile || BrandingProfile.global_default
    @organization = Agency.find(1)

    mail(to: @policy.primary_user.email,
         bcc: 'systememails@getcovered.io',
         subject: 'Policy Submission Received')
  end

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