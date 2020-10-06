module UserCoverages
  class RentGuaranteeMailer < UserCoverageMailer
    def proof_of_coverage
      attach_all_documents
      @login_url = "#{BrandingProfiles::FindByObject.run!(object: @policy.agency)&.url}/auth/login"
      @contact_email = @contact_email = branding_profile&.branding_profile_attributes&.find_by_name('contact_email')&.value
      @pensio_will_pay = @policy.policy_application.fields['monthly_rent'].to_f * @policy.policy_application.fields["guarantee_option"].to_i
      mail(subject: 'Congratulations on Your New Rent Guarantee Policy')
    end
  end
end
