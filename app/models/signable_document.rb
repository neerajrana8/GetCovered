

class SignableDocument < ApplicationRecord
  # Concerns
  include AnalyzePdf
  # Associations
  belongs_to :signer, polymorphic: true
  belongs_to :referent, polymorphic: true
  has_one_attached :unsigned_document
  has_one_attached :signed_document
  # Scopes
  scope :current, -> { where(status: %i[BOUND BOUND_WITH_WARNING]) }
  # Enums
  enum document_type: {
    deposit_choice_bond: 0
  }
  # Constants
  MIN_PDF_BYTE_COUNT_FOR_TEMP_FILE = 1048576
  
  
  
  # call this to get an access token to allow signing without logging in
  def create_access_token
    return AccessToken.create({
      bearer: self.signer,
      access_type: 'document_signature',
      access_data: {
        'signable_document_id' => self.id
      }
    })
  end
  
  # call this after unsigned_document is attached to process it for metadata
  def process_unsigned_document
    case self.document_type
      when 'deposit_choice_bond'
        s
    end
  end
  
  private
  
    def get_pdf_pages(for_signed_document: false)
      doc = (for_signed_document ? self.signed_document : self.unsigned_document)
      pages = nil
      begin
        if doc.size < SignableDocument::MIN_PDF_BYTE_COUNT_FOR_TEMP_FILE
          pages = self.read_pdf(StringIO.new(doc.download))
        else
          tmp = Tempfile.new(encoding: 'ascii-8bit')
          tmp.write(doc.download)
          pages = self.read_pdf(tmp)
          tmp.unlink
        end
      rescue
        pages = nil
      end
      return pages
    end
  
end
