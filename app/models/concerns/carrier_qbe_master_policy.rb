# =QBE Master Policy Functions Concern
# file: +app/models/concerns/carrier_qbe_master_policy.rb+

module CarrierQbeMasterPolicy
  extend ActiveSupport::Concern

  included do

    def qbe_generate_master_document(document, args)
      # ["evidence_of_insurance"].include?(document)

      document_file_title = "eoi-master-#{ id }-#{ Time.current.strftime("%Y%m%d") }.pdf"

      pdf = WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          "v2/qbe_specialty/#{ document }",
          locals: args
        )
      )

      # then save to a file
      FileUtils::mkdir_p "#{ Rails.root }/tmp/eois"
      save_path = Rails.root.join('tmp/eois', document_file_title)

      File.open(save_path, 'wb') do |file|
        file << pdf
      end

      # if documents.attach(io: File.open(save_path), filename: "evidence-of-insurance.pdf", content_type: 'application/pdf')
      #   File.delete(save_path) if File.exist?(save_path)
      # end
    end

  end
end