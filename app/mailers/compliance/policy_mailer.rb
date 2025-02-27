module Compliance
  class PolicyMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'
    before_action :set_variables

    def policy_expiring_soon(policy:)
      @user = policy.primary_user
      @pm_account = policy.account
      #TODO: it missed spanish translation
      @content = t('policy_mailer.policy_expiring_soon.content', first_name: @user&.profile&.first_name, policy_expiration_date: policy&.expiration_date.strftime('%B %d, %Y')  )

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : t('policy_verify_email')

      mail(to: @user.contact_email,
           bcc: t('system_email'),
           from: @from,
           subject: t('policy_mailer.policy_expiring_soon.subject'),
           template_path: 'compliance/policy',
           template_name: 'text_only')
    end

    def policy_lapsed(policy:, lease:)
      #Todo: Fix this pile of awful as soon as we understand why this mailer is going out 40+ times per user
      @policy = policy
      @lease = lease
      unless @policy.users.blank?
        @street_address = @policy&.primary_insurable&.primary_address()
        @address = @street_address.nil? ? nil : "#{ @street_address.combined_street_address }, #{ @policy&.primary_insurable.title }, #{ @street_address.city }, #{ @street_address.state }, #{ @street_address.zip_code }"
      
        @user = @policy.primary_user()
        @community = @policy&.primary_insurable&.parent_community
        @pm_account = @community.account
      
        @onboarding_url = tokenized_url(@user.id, @community)
        available_lease_date = @lease.nil? ? DateTime.current.to_date : @lease.sign_date.nil? ? @lease.start_date : @lease.sign_date
      
        set_master_policy_and_configuration(@community, 2, available_lease_date)
      
        @min_liability = @community.coverage_requirements_by_date(date: available_lease_date).last&.amount
      
        @placement_cost = @configuration.nil? ? 0 : @configuration.total_placement_amount(true).to_f / 100
      
        @from = @pm_account&.contact_info&.has_key?("contact_email") &&
          !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] :
                  t('policy_verify_email')
      
        mail(to: @user.contact_email,
             bcc: t('system_email'),
             from: @from,
             subject: t('policy_mailer.out_of_compliance.subject'),
             template_path: 'compliance/policy')
      end
    end

    def enrolled_in_master(user:, community:, force:, cutoff_date: DateTime.current.to_date)
      get_insurable_liability_range(community)
      set_master_policy_and_configuration(community, 2, cutoff_date)

      @user = user
      @community = community
      @pm_account = @community.account || @policy.account
      @placement_cost = @configuration.nil? ? 0 : @configuration.total_placement_amount(force).to_f / 100
      @onboarding_url = tokenized_url(@user.id, @community, @branding_profile)

      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : t('policy_verify_email')

      mail(to: @user.contact_email,
           bcc: t('system_email'),
           from: @from,
           subject: t('policy_mailer.enrolled_in_master.subject'),
           template_path: 'compliance/policy')
    end

    def external_policy_status_changed(policy:)
      @policy = policy
      @user = @policy.primary_user

      set_locale(@user&.profile&.language || "en")

      @community = @policy.primary_insurable.parent_community
      @pm_account = @community.account || @policy.account

      @onboarding_url = tokenized_url(@user.id, @community, "upload-coverage-proof", @branding_profile)

      @from = nil
      unless @pm_account.nil?
        @from = @pm_account&.contact_info["contact_email"] if @pm_account&.contact_info&.has_key?("contact_email") &&
          (!@pm_account&.contact_info["contact_email"].nil? || !@pm_account&.contact_info["contact_email"].blank?)
      end
      @from = t('policy_verify_email') if @from.blank?
      @final = nil

      case @policy.status
      when "EXTERNAL_UNVERIFIED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_submitted_email.subject')
      when "EXTERNAL_VERIFIED"
        subject = t('invitation_to_pm_tenant_portal_mailer.policy_accepted_email.subject')
      when "EXTERNAL_REJECTED"
        if @policy.status_changed_on <= DateTime.current - 7.days
          @final = true
          subject = t('invitation_to_pm_tenant_portal_mailer.policy_declined_email.subject')
        else
          @final = false
          subject = t('invitation_to_pm_tenant_portal_mailer.policy_declined_email.subject')
        end
      end

      sending_condition = @policy.policy_in_system == false &&
        ['EXTERNAL_UNVERIFIED','EXTERNAL_VERIFIED','EXTERNAL_REJECTED'].include?(@policy.status)

      bcc_emails = [t('system_email')]

      #TODO: need to figure out across the mailers logic what need to be shown in case when no relation with account or with agency
      @pm_account = @policy.account if @pm_account.nil?

      @pm_account.staffs.each do |staff|
        bcc_emails << staff.email if need_to_add_staff_to_bcc?(staff)
      end

      bcc_emails = bcc_emails.join("; ")

      mail(to: @user.contact_email,
           bcc: bcc_emails,
           from: @from,
           subject: subject,
           template_path: 'compliance/policy') if sending_condition
    end

    private
    #TODO: need to move to service objects
    def need_to_add_staff_to_bcc?(staff)
      notification_setting_enabled?(staff) && community_assigned?(staff)
    end

    def notification_setting_enabled?(staff)
      staff.notification_settings.find_by(action: 'external_policy_emails_copy', enabled: true)
    end

    def community_assigned?(staff)
      staff.assignments.find_by(assignable_type: "Insurable", assignable_id: @community.id)
    end

    def set_variables
      @organization = set_organization
      @address = @organization.addresses.where(primary: true).nil? ? Address.find(1) : @organization.primary_address()
      @branding_profile = set_branding_profile
      @GC_ADDRESS = Agency.get_covered.primary_address.nil? ? Address.find(1) : Agency.get_covered.primary_address
    end

    def set_master_policy_and_configuration(community, carrier_id, cutoff_date = nil)
      @master_policy = community&.policies&.where(policy_type_id: 2, carrier_id: carrier_id)&.take
      @configuration = @master_policy&.find_closest_master_policy_configuration(community, cutoff_date)
    end
    #  .branding_profiles&.take&.url
    #TODO: need to confirm logic and move to ApplicationMailer to make possible to use for all
    def set_organization
      if params[:organization].blank?
        @policy.account || @policy.agency || Agency.get_covered
      else
        params[:organization]
      end
    end

    def set_branding_profile
      if is_second_nature?
        #@organization.branding_profiles.blank? ? @organization.agency.branding_profiles.where(enabled: true, default: true).take : @organization.branding_profiles.where(enabled: true, default: true).take
        if Rails.env.development? or ENV['RAILS_ENV'] == 'awsdev'
          BrandingProfile.find_by(profileable_type: "Account", profileable_id: 40) || @organization.branding_profiles.where(enabled: true, default: true).take
        else
          BrandingProfile.find_by(profileable_type: "Account", profileable_id: 46) || @organization.branding_profiles.where(enabled: true, default: true).take
        end
      else
        @organization.branding_profiles.where(enabled: true, default: true)&.take || BrandingProfile.global_default
        #branding_profile_to_use
      end
    end

    def is_second_nature?
      #TODO: need to move hardcoded id to env dependant logic
      @second_nature_condition = false
      @second_nature_condition = true if @organization.is_a?(Agency) && (@organization.id == 416 || @organization.id == 11)
      @second_nature_condition = true if @organization.is_a?(Account) && (@organization.agency_id == 416 || @organization.agency_id == 11)
      @second_nature_condition
    end

  end
end
