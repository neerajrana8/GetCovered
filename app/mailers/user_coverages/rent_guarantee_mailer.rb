module UserCoverages
  class RentGuaranteeMailer < UserCoverageMailer
    def proof_of_coverage
      attach_all_documents
      branding_profile = BrandingProfiles::FindByObject.run!(object: @policy.agency)
      @login_url = "#{branding_profile&.url}/auth/login"
      @contact_email = branding_profile&.branding_profile_attributes&.find_by_name('contact_email')&.value
      @pensio_will_pay = @policy.policy_application.fields['monthly_rent'].to_f * @policy.policy_application.fields["guarantee_option"].to_i
      mail(subject: I18n.t('user_coverage_mailer.rent_guarantee.proof_of_coverage.subject'))
    end
  end
end
