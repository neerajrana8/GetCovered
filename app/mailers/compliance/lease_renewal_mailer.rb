module Compliance
  class LeaseRenewalMailer < ApplicationMailer
    include ::ComplianceMethods
    layout 'branded_mailer'
    before_action :set_variables
    
    def reminder()
      @to = user.contact_email
      return false if @to.blank? || !@to.index("@")
      set_locale("en")
      @from = @pm_account&.contact_info&.has_key?("contact_email") && !@pm_account&.contact_info["contact_email"].nil? ? @pm_account&.contact_info["contact_email"] : "policyverify@getcovered.io"
      subject = "Lease Renewal Insurance Update"
      template = 'reminder'
      mail(
        from: @from,
        to: @to,
        bcc: t('system_email'),
        subject: subject,
        template_path: 'compliance/lease_renewal',
        template_name: template
      )
    end

    private

    def set_variables
      @lease = params[:lease]
      @organization = @lease.account
      @community = @lease.insurable.parent_community
      @user = @lease.primary_user
      @pm_account = @organization
    end

    #TODO: hotfix will be moved to separate service with PolicyMailer logic in GCVR2-1028
    def set_branding_profile
      if is_second_nature?
        #@organization.branding_profiles.blank? ? @organization.agency.branding_profiles.where(enabled: true).take : @organization.branding_profiles.where(enabled: true).take
        if Rails.env.development? or ENV['RAILS_ENV'] == 'awsdev'
          BrandingProfile.find_by(profileable_type: "Account", profileable_id: 40) || @organization.branding_profiles.where(enabled: true).take
        else
          BrandingProfile.find_by(profileable_type: "Account", profileable_id: 46) || @organization.branding_profiles.where(enabled: true).take
        end
      else
        #TODO: need to be removed after mergin GCVR2-643 but retested as it bug fix from GCVR2-1209

        possible_branding = @organization.branding_profiles.where(enabled: true)&.take
        if possible_branding.blank?
          @organization.is_a?(Account) ? @organization.agency.branding_profiles.where(enabled: true).take : Agency.get_covered.branding_profiles.where(enabled: true).take
        else
          possible_branding
        end
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
