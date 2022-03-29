module Compliance
  class PolicyMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'
    before_action :set_variables

    def policy_expiring_soon(policy:)
      @user = policy.primary_user()
      @content = "Hello, Resident First Name!<br><br>
                  Your insurance policy on file with us is set to expire on #{ policy.expiration_date.strftime('%B %d, %Y') }.
                  Please submit your new insurance policy or renewal documents before the expiration date.Thank you!"

      from = policy&.account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"
      subject = "Your insurance will expire soon!"

      mail(to: @user.email,
           from: from,
           subject: subject,
           template_path: 'compliance/policy',
           template_name: 'text_only')
    end

    def policy_lapsed(policy:)
      @user = policy.primary_user()
      @content = "Hi #{ @user.profile.first_name },<br><br><strong>Your policy has lapsed or is canceled.</strong>  You
                  are out of compliance with your lease agreement and subject to being enrolled into the default community
                  policy. Please reinstate your insurance policy or upload your new policy information
                  <a href=\"https://#{ @branding_profile&.url }/pma-tenant-onboarding\">on our portal</a> for review."

      from = policy&.account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"
      subject = "You are out of compliance"
      mail(to: @user.email,
           from: from,
           subject: subject,
           template_path: 'compliance/policy',
           template_name: 'text_only')
    end

    def enrolled_in_master(user:, community:, force:)
      set_master_policy_and_configuration(community, 2)

      liability_coverage = @master_policy.policy_coverages.where(designation: "liability_coverage").take
      contents_coverage = @master_policy.policy_coverages.where(designation: "tenant_contingent_contents").take

      @content = "Hi #{ user.profile.first_name },<br><br><strong>Default policy activated. The default policy has been
                  activated in compliance with the insurance requirement per your lease agreement. You will be charged
                  $#{ sprintf "%.2f", @configuration.charge_amount(force).to_f / 100 } each month. The
                  community policy includes $#{ sprintf "%.2f", liability_coverage.to_f / 100 } in property
                  liability coverage and $#{ sprintf "%.2f", contents_coverage.to_f / 100 } in contents coverage
                  <strong>(contents if applicable)</strong>."

      from = policy&.account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"
      subject = "Default Policy Enrollment"
      mail(to: user.email,
           from: from,
           subject: subject,
           template_path: 'compliance/policy',
           template_name: 'text_only')
    end

    def external_policy_status_changed(policy:)
      @policy = policy
      @user = @policy.primary_user

      set_locale(@user.profile&.language)

      @community = @policy.primary_insurable.parent_community
      @pm_account = @community.account

      @onboarding_url = tokenized_url(@user, @community)

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"

      case @policy.status
      when "EXTERNAL_UNVERIFIED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_submitted_email.subject')
      when "EXTERNAL_VERIFIED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_accepted_email.subject')
      when "EXTERNAL_REJECTED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_declined_email.subject')
      end

      mail(from: @from, to: @user.email, subject: subject, template_path: 'compliance/policy')
    end

    private

    def set_variables
      @organization = params[:organization]
      @address = @organization.primary_address()
      @branding_profile = @organization.branding_profiles.where(default: true).take
    end

    def set_master_policy_and_configuration(community, carrier_id)
      @master_policy = community.policies.where(policy_type_id: 2, carrier_id: carrier_id).take
      @configuration = @master_policy.find_closest_master_policy_configuration(community)
    end

  end
end