module Compliance
  class PolicyMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'
    before_action :set_variables

    def policy_expiring_soon(policy:)
      @user = policy.primary_user()
      @pm_account = policy.account
      @content = "Hello, #{ @user.profile.first_name }!<br><br>
                  Your insurance policy on file with us is set to expire on #{ policy.expiration_date.strftime('%B %d, %Y') }.
                  Please submit your new insurance policy or renewal documents before the expiration date.Thank you!"

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"

      subject = "Your insurance will expire soon!"

      mail(to: @user.contact_email,
           bcc: "systememails@getcovered.io",
           from: @from,
           subject: subject,
           template_path: 'compliance/policy',
           template_name: 'text_only')
    end

    def policy_lapsed(policy:, lease:)
      @policy = policy
      @lease = lease
      @street_address = @policy&.primary_insurable&.primary_address()
      @address = @street_address.nil? ? nil : "#{ @street_address.combined_street_address }, #{ @policy&.primary_insurable.title }, #{ @street_address.city }, #{ @street_address.state }, #{ @street_address.zip_code }"

      @user = @policy.primary_user()
      @pm_account = @policy.account
      @community = @policy&.primary_insurable&.parent_community

      @onboarding_url = tokenized_url(@user, @community)
      get_insurable_liability_range(@community)
      set_master_policy_and_configuration(@community, 2)

      @placement_cost = @configuration.nil? ? 0 : @configuration.charge_amount(true).to_f / 100

      @from = @pm_account&.contact_info&.has_key?("contact_email") &&
        !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] :
                "policyverify@getcovered.io"

      mail(to: @user.contact_email,
           bcc: "systememails@getcovered.io",
           from: @from,
           subject: "You are out of compliance",
           template_path: 'compliance/policy')
    end

    def enrolled_in_master(user:, community:, force:)
      get_insurable_liability_range(community)
      set_master_policy_and_configuration(community, 2)

      @user = user
      @community = community
      @pm_account = @community.account
      @placement_cost = @configuration.nil? ? 0 : @configuration.charge_amount(force).to_f / 100
      @onboarding_url = tokenized_url(@user, @community)

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"

      mail(to: @user.contact_email,
           bcc: "systememails@getcovered.io",
           from: @from,
           subject: "Default Policy Enrollment",
           template_path: 'compliance/policy')
    end

    def external_policy_status_changed(policy:)
      @policy = policy
      @user = @policy.primary_user

      set_locale(@user.profile&.language)

      @community = @policy.primary_insurable.parent_community
      @pm_account = @community.account

      @onboarding_url = tokenized_url(@user, @community)

      @from = nil
      unless @pm_account.nil?
        @from = @pm_account&.contact_info["contact_email"] if @pm_account&.contact_info&.has_key?("contact_email") &&
          (!@pm_account&.contact_info["contact_email"].nil? || !@pm_account&.contact_info["contact_email"].blank?)
      end
      @from = "policyverify@getcovered.io" if @from.nil?

      case @policy.status
      when "EXTERNAL_UNVERIFIED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_submitted_email.subject')
      when "EXTERNAL_VERIFIED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_accepted_email.subject')
      when "EXTERNAL_REJECTED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_declined_email.subject')
      end

      sending_condition = @policy.policy_in_system == false &&
        ['EXTERNAL_UNVERIFIED','EXTERNAL_VERIFIED','EXTERNAL_REJECTED'].include?(@policy.status)

      mail(to: @user.contact_email,
           bcc: "systememails@getcovered.io",
           from: @from,
           subject: subject,
           template_path: 'compliance/policy') if sending_condition
    end

    private

    def set_variables
      @organization = params[:organization].blank? ? Agency.find(1) : params[:organization]
      @address = @organization.addresses.where(primary: true).nil? ? Address.find(1) : @organization.primary_address()
      @branding_profile = @organization.branding_profiles.where(default: true).take
      @GC_ADDRESS = Agency.get_covered.primary_address.nil? ? Address.find(1) : Agency.get_covered.primary_address
    end

    def set_master_policy_and_configuration(community, carrier_id)
      @master_policy = community.policies.where(policy_type_id: 2, carrier_id: carrier_id).take
      @configuration = @master_policy.find_closest_master_policy_configuration(community)
    end

  end
end