# =Pensio Policy Functions Concern
# file: +app/models/concerns/carrier_pensio_policy.rb+

module CarrierPensioPolicy
  extend ActiveSupport::Concern

  included do
	  
	  # Crum Issue Policy
    
    def pensio_issue_policy
      return nil unless policy_in_system
      
      agreement = "agreement-#{ self.number }.pdf"
      summary = "summary-#{ self.number }.pdf"

      agreement_pdf = WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          "v2/pensio/evidence_of_insurance", 
          locals: { 
            :@policy => self
          }
        )
      )

      summary_pdf = WickedPdf.new.pdf_from_string(ActionController::Base.new.render_to_string("v2/pensio/summary", locals: {:@policy => self}))
      
      FileUtils::mkdir_p "#{ Rails.root }/tmp/eois"
      agreement_save_path = Rails.root.join('tmp/eois', agreement)
      summary_save_path = Rails.root.join('tmp/eois', summary)
      
      File.open(agreement_save_path, 'wb') do |file|
        file << agreement_pdf
      end
      
      File.open(summary_save_path, 'wb') do |file|
        file << summary_pdf
      end
      
      if documents.attach(io: File.open(agreement_save_path), filename: "#{ number }-agreement.pdf", content_type: 'application/pdf')
				File.delete(agreement_save_path) if File.exist?(agreement_save_path) 	
			end
      
      if documents.attach(io: File.open(summary_save_path), filename: "#{ number }-summary.pdf", content_type: 'application/pdf')
				File.delete(summary_save_path) if File.exist?(summary_save_path) 	
			end
      
    end
    
  end
end