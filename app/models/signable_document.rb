# == Schema Information
#
# Table name: signable_documents
#
#  id            :bigint           not null, primary key
#  title         :string           not null
#  document_type :integer          not null
#  document_data :jsonb
#  status        :integer          default("preparing_document"), not null
#  errored       :boolean          default(FALSE), not null
#  error_data    :jsonb
#  signed_at     :datetime
#  signer_type   :string
#  signer_id     :bigint
#  referent_type :string
#  referent_id   :bigint
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require 'base64'

class SignableDocument < ApplicationRecord
  # Concerns
  include AnalyzePdf
  # Associations
  belongs_to :signer, polymorphic: true
  belongs_to :referent, polymorphic: true
  has_one_attached :unsigned_document
  has_one_attached :signed_document
  has_many :events, as: :eventable
  # Callbacks
  before_save :set_signed_at,
    if: Proc.new{|sd| sd.status == 'signed' && sd.will_save_change_to_attribute?('status') }
  after_save :clear_errors,
    if: Proc.new{|sd| sd.saved_change_to_attribute?('status') && self.errored && !sd.saved_change_to_attribute?('errored') }
  # Enums
  enum document_type: {
    deposit_choice_bond: 0
  }
  enum status: {
    preparing_document: 0,  # we've been created, but we have no unsigned_document attached yet and no one has called process_unsigned_document
    unsigned: 1,            # we have a document and have been processed, but have not been signed
    signed: 2               # we have been signed
  }
  # Constants
  MIN_PDF_BYTE_COUNT_FOR_TEMP_FILE = 1048576
  ERROR_DICTIONARY = { # MOOSE WARNING: put these in translated phrases thing if we ever give them to the user, which right now we don't
    unable_to_parse: {
    },
    unable_to_find_date_label: {
    },
    unable_to_find_signature_block: {
    },
    unknown_error: {
    },
    error_while_signing: {
    },
    deposit_choice_upload_failed: {
    }
  }
  
  
  # whether anything prevents this from being signed right now
  def signable?
    return(self.status == 'unsigned')
  end
  
  def signed?
    return(self.status == 'signed')
  end
  
  
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
  
  # get hash to show client (could move into a jbuilder view but unlike most models doesn't necessarily correspond well with fields)
  def client_view
    case self.document_type
      when 'deposit_choice_bond'
        if self.status == 'unsigned'
          return {
            document_type: 'deposit_choice_bond',
            title: self.title,
            document_url: self.unsigned_document.service_url,
            geometry: self.document_data['geometry_for_client']
          }
        elsif self.status == 'signed'
          return {
            document_type: 'deposit_choice_bond',
            title: self.title,
            document_url: self.signed_document.service_url
          }
        end
    end
    return nil
  end
  
  # call this after unsigned_document is attached to process it for metadata
  def process_unsigned_document
    return if self.status != 'preparing_document' || self.unsigned_document.nil?
    case self.document_type
      when 'deposit_choice_bond'
        # grab date label and signature block
        all_looks_good = false
        pages = get_pdf_pages
        date_label = nil
        signature_block = nil
        if pages
          date_label = find_in_pdf(pages){|text| text.index("Signed on this date:") }
          signature_block = find_in_pdf(pages, with_previous_y: true){|text| text.gsub(" ", "").index("[s:a:r]") }
          all_looks_good = (!date_label.nil? && !signature_block.nil?)
        end
        if !all_looks_good
          self.update({
            errored: true,
            error_data: {
              'error' =>  pages.nil? ? 'unable_to_parse' :
                          date_label.nil? ? 'unable_to_find_date_label' :
                          signature_block.nil? ? 'unable_to_find_signature_block' :
                          'unknown_error'
            }
          })
          return false
        end
        page_width = pages[signature_block[:page_number] - 1][:info][:media_box][2] - pages[signature_block[:page_number] - 1][:info][:media_box][0]
        sig_width = [6 * (signature_block[:previous_y] - signature_block[:y]), page_width - signature_block[:x]].min  # the line extends to the end of the page, so we just pick something reasonable
        self.update({
          status: 'unsigned',
          document_data: {
            'signature_overlay_page' => signature_block[:page_number],
            'date_label' => {
              'x' => date_label[:x] + date_label[:width],
              'y' => date_label[:y]
            },
            'signature_block' => {
              'x' => signature_block[:x],
              'y' => signature_block[:y],
              'width' => sig_width,
              'height' => signature_block[:previous_y] - signature_block[:y]
            },
            'geometry_for_client' => {
              'document_dimensions' => {
                'width' => page_width,
                'height' => pages[signature_block[:page_number] - 1][:info][:media_box][3] - pages[signature_block[:page_number] - 1][:info][:media_box][1]
              },
              'signature_block' => {
                'page_number' => signature_block[:page_number],
                'x' => signature_block[:x] - pages[signature_block[:page_number] - 1][:info][:media_box][0],
                'y' => signature_block[:y] - pages[signature_block[:page_number] - 1][:info][:media_box][1],
                'width' => sig_width,
                'height' => signature_block[:previous_y] - signature_block[:y]
              },
              'date_block' => {
                'page_number' => date_label[:page_number],
                'x' => date_label[:x] + date_label[:width],
                'y' => date_label[:y]
              }
            }
          }
        })
    end
  end
  
  
  def sign_document(signature_image, extra_params = nil)
    return false if self.status != 'unsigned'
    case self.document_type
      when 'deposit_choice_bond'
        return false if self.referent_type != 'Policy'
        begin
          # MOOSE WARNING: we don't check signature dimensions against dd['signature_block']['width'] and ['height'] here, but we might want to
          dd = self.document_data
          # generate signature overlay
          unsigned_template = get_file(force_tempfile: true)
          signature_tempfile = Tempfile.new
          Prawn::Document.generate(signature_tempfile, template: unsigned_template) do |pdf|
            pdf.image signature_image, at: [dd['signature_block']['x'].to_f, dd['signature_block']['y'].to_f], scale: 1.0
            pdf.text_box "#{Time.current.to_date.to_s}", at: [dd['date_label']['y'].to_f, dd['date_label']['x'].to_f]
          end
          # combine original with signature overlay
          overlay = CombinePDF.load(signature_tempfile.path).pages[0]
          combined = CombinePDF.load(unsigned_template.path)
          combined.pages[dd['signature_overlay_page'] - 1] << overlay
          combined.save(unsigned_template)
          unsigned_template.rewind
          # attach signed document
          self.signed_document.attach(io: unsigned_template, filename: DepositChoiceService.signed_document_filename, content_type: 'application/pdf')
          unsigned_template.rewind
        rescue StandardError => error
          self.update({
            errored: true,
            error_data: {
              error: 'error_while_signing',
              error_class: error.class.name,
              error_message: error.message
            }
          })
          return false
        end
        self.update(status: 'signed')
        # try to upload
        self.try_deposit_choice_upload(pdf_base64: Base64.strict_encode64(unsigned_template.read)) rescue self.update({ errored: true, error_data: { error: 'deposit_choice_upload_failed', failed_at: Time.current.to_s } })
        # return success
        return true
    end
  end
  
  def try_deposit_choice_upload(pdf_base64: nil)
    return false if self.document_type != 'deposit_choice_bond' || self.referent_type != 'Policy' || self.status != 'signed'
    dcs = DepositChoiceService.new
    dcs.build_request(:upload,
      policy_number: self.referent&.number,
      pdf_base64: pdf_base64 || Base64.strict_encode64(signed_document.download)
    )
    event = self.events.new(dcs.event_params)
    event.started = Time.now
    result = dcs.call
    event.completed = Time.now
    event.response = result[:response].response.body
    event.status = result[:error] ? 'error' : 'success'
    event.save
    if result[:error]
      self.update({
        errored: true,
        error_data: {
          error: 'deposit_choice_upload_failed',
          event_id: event.id,
          failed_at: Time.current.to_s
        }
      })
      return false
    end
    self.update({
      errored: false,
      error_data: {}
    })
    return true    
  end
  
  private
  
    def get_file(for_signed_document: false, force_tempfile: false)
      doc = (for_signed_document ? self.signed_document : self.unsigned_document)
      file_to_return = nil
      begin
        if !force_tempfile && doc.byte_size < SignableDocument::MIN_PDF_BYTE_COUNT_FOR_TEMP_FILE
          file_to_return = StringIO.new(doc.download)
        else
          tmp = Tempfile.new(encoding: 'ascii-8bit')
          tmp.write(doc.download)
          file_to_return = tmp
        end
      rescue
        file_to_return = nil
      end
      return file_to_return
    end
  
    def get_pdf_pages(for_signed_document: false)
      doc = (for_signed_document ? self.signed_document : self.unsigned_document)
      pages = nil
      begin
        if doc.byte_size < SignableDocument::MIN_PDF_BYTE_COUNT_FOR_TEMP_FILE
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
    
    def set_signed_at
      self.signed_at = Time.current
    end
    
    def clear_errors
      self.errored = false
      self.error_data = nil
      self.save # this is called in after_save, but the condition thereupon will prevent a loop if errored is false
    end
    
  
end
