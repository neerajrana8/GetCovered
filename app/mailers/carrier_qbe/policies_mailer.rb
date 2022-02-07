module CarrierQBE
  class PoliciesMailer < ApplicationMailer
    before_action { @user = params[:user] }
    before_action { @policy = params[:policy] }
    before_action :check_carrier

    def proof_of_coverage
      @user_name = @user&.profile&.full_name
      I18n.locale = @user&.profile&.language if @user&.profile&.language&.present?
      @accepted_on = Time.current.strftime('%m/%d/%y')
      @site = whitelabel_host(@policy.agency)

      @content = {
        subject: I18n.t('user_coverage_mailer.all_documents.other_title'),
        text: 'Your Renters Insurance Policy has been accepted on ' + @accepted_on  +'.</br>
             Please log in to <a href="' + @site + '">our site</a> for more information.'
      }

      attachments["evidence-of-insurance.pdf"] = {
        mime_type: "application/pdf",
        encoding: "base64",
        content: Base64.strict_encode64(@policy.documents.last.download)
      }

      mail(subject: @content[:subject])
    end

    private
      def check_carrier
        raise ArgumentError.new("Policy must be specified") if @policy.nil? || !@policy.is_a?(Policy)
        raise ArgumentError.new("Policy must be residential") unless @policy.policy_type_id == 1
        raise ArgumentError.new("Policy must be issued by QBE") unless @policy.carrier_id == 1
      end

      def whitelabel_host(agency)
        BrandingProfiles::FindByObject.run!(object: agency)&.url ||
          Rails.application.credentials.uri[ENV['RAILS_ENV'].to_sym][:client]
      end
  end
end