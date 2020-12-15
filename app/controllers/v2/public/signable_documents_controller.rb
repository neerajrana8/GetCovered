##
# V2 Public Signable Documents Controller
# File: app/controllers/v2/public/signable_documents_controller.rb

module V2
  module Public
    class SignableDocumentsController < PublicController
    
    
      # whatever?token=8h9afjeJfeanfa3npfa9983ah93fuawgoha33g0aga
      
      def get_unsigned_document
        # get the document
        token = ::AccessToken.from_urlparam(params[:token])
        doc = token.nil? || token.access_type != 'document_signature' ? nil : ::SignableDocument.where(id: token.access_data&.[]('signable_document_id')).take
        if doc.nil? || !doc.signable?
          render json: standard_error(:document_not_found, 'Document not found'), # MOOSE WARNING: translate!!!!
            status: 401
          return
        end
        # return the document
        render json: doc.client_view,
          status: 200
      end
      
      
      def sign_document
        # get the document
        token = ::AccessToken.from_urlparam(params[:token])
        doc = token.nil? || token.access_type != 'document_signature' ? nil : ::SignableDocument.where(id: token.access_data&.[]('signable_document_id')).take
        if doc.nil? || doc.signable?
          render json: standard_error(:document_not_found, 'Document not found'), # MOOSE WARNING: translate!!!!
            status: 401
          return
        end
        # get the signature image
        signature_image = StringIO.new(Base64.decode64(sign_document_params[:signature])) rescue nil
        # MOOSE WARNING: validate file type? validate dimensions?
        result = doc.sign_document(signature_image)
        unless result
          render standard_error(:signing_failed, "An error occurred while trying to apply your signature; please try again later"), # MOOSE WARNING: translate!!! use I18n.t('signable_document_contr.sign_document.signing_failed')),
            status: 400
          return
        end
        render json: doc.client_view,
          status: 200
      end
    
    
      private
      
        def sign_document_params
          params.permit(:signature)
        end
    
    
    end
  end
end
