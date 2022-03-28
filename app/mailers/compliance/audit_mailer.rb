module Compliance
  class AuditMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'

    def intro(user:, community:, lease_start_date:, follow_up:)
      raise ArgumentError.new(
        "Expected a follow up value of 0 to 2, got #{ follow_up }"
      ) if follow_up.nil? || follow_up > 2

      @user = user
      @community = community
      @onboarding_url = tokenized_url(@user, @community)
      @requirements_date = lease_start_date + @configuration.grace_period
      @pm_account = @community.account

      case follow_up
      when 0
        subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_1.subject')
        template = 'intro'
      when 1
        subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_2.subject')
        template = 'intro_first_follow_up'
      when 2
        subject = t('invitation_to_pm_tenant_portal_mailer.audit_email_3.subject')
        template = 'intro_second_follow_up'
      end

      # Hard coded to QBE for now.
      master_policy_and_configuration(@community, 2)
      set_liabilities(@community)
      set_locale(@user.profile&.language)

      mail(from: @pm_account.contact_info["contact_email"],
           to: @user.email,
           subject: subject,
           template_path: 'compliance/audit',
           template_name: template)
    end

    private

    def master_policy_and_configuration(community:, carrier_id:)
      @master_policy = community.policies.where(policy_type_id: 2, carrier_id: carrier_id).take
      @configuration = @master_policy.find_closest_master_policy_configuration(community)
    end
  end
end