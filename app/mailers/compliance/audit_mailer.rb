module Compliance
  class AuditMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'
    before_action :set_variables

    def intro(user:, unit:, lease_start_date:, follow_up:, lease_sign_date: nil)
      raise ArgumentError.new(
        "Expected a follow up value of 0 to 2, got #{ follow_up.nil? ? 'nil' : follow_up }"
      ) if follow_up.nil? || follow_up > 2

      @user = user
      @unit = unit
      @community = @unit.parent_community()
      @pm_account = @community.account

      get_address = get_mailing_address(unit: @unit)
      @street_address = @community&.primary_address()
      @mailing_address = get_address[:status] == false ? get_address[:addtl_address] : @street_address
      @address = @mailing_address.nil? ? nil : "#{ @mailing_address.combined_street_address }, #{ @unit.title }, #{ @mailing_address.city }, #{ @mailing_address.state }, #{ @mailing_address.zip_code }"

      available_lease_date = lease_sign_date.nil? ? lease_start_date : lease_sign_date

      # Hard coded to QBE for now.
      set_master_policy_and_configuration(@community, 2, available_lease_date)
      get_insurable_liability_range(@community)
      set_locale(@user&.profile&.language || "en")

      @onboarding_url = tokenized_url(@user.id, @community)
      @min_liability = @community.coverage_requirements_by_date(date: available_lease_date).where(designation: 'liability')&.take&.amount

      @requirements_date = @configuration.nil? ? lease_start_date : lease_start_date + @configuration.grace_period
      @placement_cost = @configuration.nil? ? 0 : @configuration.total_placement_amount(true).to_f / 100
      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"

      sending_condition = @configuration.nil? ? false : @configuration.program_start_date.to_date <= available_lease_date ? true : false

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

      if sending_condition
        mail(from: @from,
             to: @user.contact_email,
             bcc: t('system_email'),
             subject: subject,
             template_path: 'compliance/audit',
             template_name: template)
      else
        return false
      end
    end

    private

    def set_variables
      @organization = params[:organization]
      @address = @organization.primary_address()
      @branding_profile = @organization.branding_profiles.where(default: true).take
      #TODO: need to be removed after mergin GCVR2-643 but retested as it bug fix from GCVR2-1209
      if @branding_profile.blank?
        @branding_profile = @organization.is_a?(Account) ? @organization.agency.branding_profiles.where(default: true).take : Agency.get_covered.branding_profiles.where(default: true).take
      end
      @GC_ADDRESS = Agency.get_covered.primary_address()
    end

    def set_master_policy_and_configuration(community, carrier_id, cutoff_date = nil)
      @master_policy = community.policies.where(policy_type_id: 2, carrier_id: carrier_id).take
      @configuration = @master_policy&.find_closest_master_policy_configuration(community, cutoff_date)
    end

    def get_mailing_address(unit: )
      use_community = {
        :status => true,
        :addtl_address => nil
      }

      possible_building = unit.insurable
      if possible_building.insurable_type_id == 7
        use_community[:status] = false
        use_community[:addtl_address] = possible_building.primary_address()
      end

      return use_community
    end
  end
end
