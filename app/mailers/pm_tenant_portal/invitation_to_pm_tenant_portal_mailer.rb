module PmTenantPortal
  class InvitationToPmTenantPortalMailer < ApplicationMailer

    #InvitationToPmTenantPortalMailer.audit_email_1(user: user, master_policy: master_policy).deliver_later
    #PmTenantPortal::InvitationToPmTenantPortalMailer.first_audit_email(user: User.last, master_policy: @policy).deliver_later
    # Command to test from dev console : User.find(1).invite_to_pm_tenant_portal(BrandingProfile.find(1).url, 10)
    def first_audit_email(user:, community:, tenant_onboarding_url:)
      set_locale(user.profile&.language)

      @user = user
      @community = community
      @tenant_onboarding_url = tenant_onboarding_url

      @pm_account = @community.account
      #TODO: need to remove after test
      @master_policy = @community.policies.where(policy_type_id: 2).take || Policy.last

      #@agency = master_policy.agency

      @from = @pm_account.contact_info["contact_email"]
      subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_1.subject')#,
                  #agency_title: @agency.title,
                  #policy_number: @master_policy.number)
      mail(from: @from, to: user.email, subject: subject)
    end

    #TODO: move the same parts in shared method
    # Send after 72 hours (3 days)
    def second_audit_email(user:, community:, tenant_onboarding_url:)
      set_locale(user.profile&.language)

      @user = user
      @community = community
      @tenant_onboarding_url = tenant_onboarding_url

      @pm_account = @community.account
      #TODO: need to remove after test
      @master_policy = @community.policies.where(policy_type_id: 2).take || Policy.last

      #@agency = master_policy.agency

      @from = @pm_account.contact_info["contact_email"]
      subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_2.subject')#,
      #agency_title: @agency.title,
      #policy_number: @master_policy.number)
      mail(from: @from, to: user.email, subject: subject)
    end

    # Send after 168 hours (7 days)
    def third_audit_email(user:, community:, tenant_onboarding_url:)
      set_locale(user.profile&.language)

      @user = user
      @community = community
      @tenant_onboarding_url = tenant_onboarding_url

      @pm_account = @community.account
      #TODO: need to remove after test
      @master_policy = @community.policies.where(policy_type_id: 2).take || Policy.last

      #@agency = master_policy.agency

      @from = @pm_account.contact_info["contact_email"]
      subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_3.subject')#,
      #agency_title: @agency.title,
      #policy_number: @master_policy.number)
      mail(from: @from, to: user.email, subject: subject)
    end
  end
end

