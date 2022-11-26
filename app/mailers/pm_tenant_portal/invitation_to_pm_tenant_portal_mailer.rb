module PmTenantPortal
  class InvitationToPmTenantPortalMailer < ApplicationMailer

    #InvitationToPmTenantPortalMailer.audit_email_1(user: user, master_policy: master_policy).deliver_later
    #PmTenantPortal::InvitationToPmTenantPortalMailer.first_audit_email(user: User.last, master_policy: @policy).deliver_later
    # Command to test from dev console : User.find(1).invite_to_pm_tenant_portal(BrandingProfile.find(1).url, 10)
    # User.find(1443).invite_to_pm_tenant_portal(BrandingProfile.find(45).url, 10035)
    def first_audit_email(user:, community:, tenant_onboarding_url:, lease_start_date:)
      set_locale(user.profile&.language)

      @user = user
      @community = community
      @tenant_onboarding_url = tenant_onboarding_url
      @requirement_date = lease_start_date.nil? ? DateTime.current : lease_start_date

      @pm_account = @community.account
      #TODO: need to remove after test
      @master_policy = @community.policies.where(policy_type_id: 2).take || Policy.last

      set_liabilities(@community)
      #@agency = master_policy.agency

      @from = @pm_account.contact_info["contact_email"]
      subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_1.subject')#,
                  #agency_title: @agency.title,
                  #policy_number: @master_policy.number)
      mail(from: @from, to: user.email, subject: subject)
    end

    #TODO: move the same parts in shared method
    # Send after 72 hours (3 days)
    def second_audit_email(user:, community:, tenant_onboarding_url:, lease_start_date:)
      set_locale(user.profile&.language)

      @user = user
      @community = community
      @tenant_onboarding_url = tenant_onboarding_url
      @requirement_date = lease_start_date.nil? ? DateTime.current : lease_start_date

      set_liabilities(@community)

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
    def third_audit_email(user:, community:, tenant_onboarding_url:, lease_start_date:)
      set_locale(user.profile&.language)

      @user = user
      @community = community
      @tenant_onboarding_url = tenant_onboarding_url
      @requirement_date = lease_start_date.nil? ? DateTime.current : lease_start_date

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

    def external_policy_submitted(user_email:, community_id:, policy_id:)
      @user = User.find_by_email(user_email)

      set_locale(@user.profile&.language)

      @community = Insurable.find_by_id(community_id)
      set_liabilities(@community)

      @review_number = policy_id
      @pm_account = @community.account

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info&.fetch("contact_email", nil).blank? ? @pm_account&.contact_info&.fetch("contact_email") : "policyverify@getcovered.io"
      subject = t('invitation_to_pm_tenant_portal_mailer.policy_submitted_email.subject')

      mail(from: @from, to: @user.email, subject: subject)
    end

    def external_policy_accepted(policy:)
      @policy = policy
      @user = @policy.primary_user

      set_locale(@user.profile&.language)

      @community = @policy.primary_insurable
      set_liabilities(@community)

      @pm_account = @community.account
      @tenant_onboarding_url = tenant_onboarding_url(@user.id, @community)

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"
      subject = t('invitation_to_pm_tenant_portal_mailer.policy_accepted_email.subject')

      mail(from: @from, to: @user.email, subject: subject)
    end

    def external_policy_declined(policy:)
      @policy = policy
      @user = @policy.primary_user

      set_locale(@user.profile&.language)

      @community = @policy.primary_insurable
      @pm_account = @community.account

      @tenant_onboarding_url = tenant_onboarding_url(@user.id, @community)

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"
      subject = t('invitation_to_pm_tenant_portal_mailer.policy_declined_email.subject')

      mail(from: @from, to: @user.email, subject: subject)
    end

    private

    def tenant_onboarding_url(user_id, community)
      branding_profile_url = community&.account&.branding_profiles&.take&.url
      str_to_encrypt = "user #{user_id} community #{community.id}" #user 1443 community 10035
      auth_token_for_email = EncryptionService.encrypt(str_to_encrypt)
      "https://#{branding_profile_url}/pma-tenant-onboarding?token=#{auth_token_for_email}"
    end

    def set_liabilities(insurable)
      account = insurable.account
      carrier_id = account.agency.providing_carrier_id(PolicyType::RESIDENTIAL_ID, insurable){|cid| (insurable.get_carrier_status(carrier_id) == :preferred) ? true : nil }
      carrier_policy_type = CarrierPolicyType.where(carrier_id: carrier_id, policy_type_id: PolicyType::RESIDENTIAL_ID).take
      uid = (carrier_id == ::MsiService.carrier_id ? '1005' : carrier_id == ::QbeService.carrier_id ? 'liability' : nil)
      liability_options = ::InsurableRateConfiguration.get_inherited_irc(carrier_policy_type, account, insurable).configuration['coverage_options']&.[](uid)&.[]('options')
      @max_liability = liability_options&.map{|opt| opt['value'].to_i }&.max
      @min_liability = liability_options&.map{|opt| opt['value'].to_i }&.min

      if @min_liability.nil? || @min_liability == 0 || @min_liability == "null"
        @min_liability = 1000000
      end

      if @max_liability.nil? || @max_liability == 0 || @max_liability == "null"
        @max_liability = 30000000
      end
    end
  end
end

