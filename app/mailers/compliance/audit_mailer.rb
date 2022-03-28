module Compliance
  class AuditMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'
    before_action :set_variables

    def intro(user:, community:, lease_start_date:, follow_up:)
      raise ArgumentError.new(
        "Expected a follow up value of 0 to 2, got #{ follow_up.nil? ? 'nil' : follow_up }"
      ) if follow_up.nil? || follow_up > 2

      @user = user
      @community = community
      @pm_account = @community.account

      # Hard coded to QBE for now.
      set_master_policy_and_configuration(@community, 2)
      get_insurable_liability_range(@community)
      set_locale(@user.profile&.language)

      @onboarding_url = tokenized_url(@user, @community)
      @requirements_date = @configuration.nil? ? lease_start_date : lease_start_date + @configuration.grace_period
      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"

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

      mail(from: @from,
           to: @user.email,
           subject: subject,
           template_path: 'compliance/audit',
           template_name: template)
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