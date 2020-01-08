# =QBE Policy Functions Concern
# file: +app/models/concerns/carrier_qbe_policy.rb+

module CarrierQbePolicy
  extend ActiveSupport::Concern
  
  included do
    
    # QBE Issue Policy
    
    def qbe_issue_policy
      return nil unless policy_in_system?
      
      # document = documents.create!(:title => "Policy ##{ id } Evidence of Insurance #{ Time.current.strftime("%m/%d/%Y") }", :system_generated => true, :file_type => "evidence_of_insurance")
      
      document_file_title = "eoi_#{ id }_#{ Time.current.strftime("%Y%m%d") }.pdf"
      
      # create a pdf from string using templates, layouts and content option for header or footer
      pdf = WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          "v2/qbe/evidence_of_insurance", 
          locals: { :@policy => self }
        )
      )
      
      # then save to a file
      FileUtils::mkdir_p "#{ Rails.root }/tmp/eois"
      save_path = Rails.root.join('tmp/eois', document_file_title)
      
      File.open(save_path, 'wb') do |file|
        file << pdf
      end
      
      # document.file = Rails.root.join('tmp/eois', document_file_title).open
      
      # if document.save!
      #   insured.each { |u| document.users << u }
      #   community.staffs.each { |s| document.staffs << s }
      #   agency.agents.each { |a| document.agents << a }
      #   document.downloads.create()
        
      #   FileUtils::remove_entry(save_path)
        
      #   return true
      # else
        
      #   return false
      # end
      
    end
    
  end
end