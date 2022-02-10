# =QBE Policy Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicy
  extend ActiveSupport::Concern
  
  included do
    
    # QBE Issue Policy
    
    def qbe_issue_policy
      return nil unless policy_in_system?
      
      document_file_title = "qbe-residential-eoi-#{ id }-#{ Time.current.strftime("%Y%m%d-%H%M%S") }.pdf"
      
      # create a pdf from string using templates, layouts and content option for header or footer
      pdf = WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          "v2/qbe/evidence_of_insurance", 
          locals: { 
            :@policy => self,
            :@policy_application => self.policy_application,
            :@agency => self.agency,
            :@address => self.agency.primary_address(),
            :@carrier_agency => CarrierAgency.where(carrier_id: self.carrier_id, agency_id: self.agency_id).take }
        ),
        page_size: 'A4',
        encoding: 'UTF-8',
        disable_smart_shrinking: true
      )
      
      # then save to a file
      FileUtils::mkdir_p "#{ Rails.root }/tmp/eois/qbe/residential"
      save_path = Rails.root.join('tmp/eois/qbe/residential', document_file_title)
      
      File.open(save_path, 'wb') do |file|
        file << pdf
      end
      
      if documents.attach(io: File.open(save_path), filename: "#{ number }-evidence-of-insurance.pdf", content_type: 'application/pdf')
				File.delete(save_path) if File.exist?(save_path) unless %w[local development].include?(ENV["RAILS_ENV"])
      end

      self.update document_status: "at_hand"
      self.reload()

      self.update document_status: "sent" if UserCoverageMailer.with(user: self.primary_user, policy: self).qbe_proof_of_coverage.deliver_now
      # CarrierQBE::PoliciesMailer.with(user: self.primary_user, policy: self).proof_of_coverage.deliver_now
    end
    
  end
end
