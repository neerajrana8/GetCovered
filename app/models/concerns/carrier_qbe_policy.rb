# =QBE Policy Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicy
  extend ActiveSupport::Concern
  
  included do
    
    # QBE Issue Policy
    
    def qbe_issue_policy
      return nil unless policy_in_system?
      
      # document = documents.create!(:title => "Policy ##{ id } Evidence of Insurance #{ Time.current.strftime("%m/%d/%Y") }", :system_generated => true, :file_type => "evidence_of_insurance")
      
      document_file_title = "qbe-residential-eoi-#{ id }-#{ Time.current.strftime("%Y%m%d-%H%M%S") }.pdf"
      
      # create a pdf from string using templates, layouts and content option for header or footer
      pdf = WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          "v2/qbe/evidence_of_insurance", 
          locals: { 
            :@policy => self,
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
      
    end
    
  end
end