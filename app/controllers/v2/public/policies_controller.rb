##
# V2 Public Policies Controller
# File: app/controllers/v2/public/policies_controller.rb

module V2
  module Public
    class PoliciesController < PublicController
    
    
      # whatever?token=8h9afjeJfeanfa3npfa9983ah93fuawgoha33g0aga
      def get_unsigned_document
        # find and validate the access token
        token = ::AccessToken.from_urlparam(params[:token])
        if token.nil? || token.access_type != 'user_document_signature'
          render json: standard_error(:document_not_found, 'Document not found'),
            status: 401
          return
        end
        # get the document
        policy = ::Policy.where(id: token.access_data&.[]('policy_id')).take
        document = policy&.documents&.where(id: token.access_data&.[]('document_id'))&.take
        if policy.nil? || document.nil? || !policy.unsigned_documents.include?(token.access_data&.[]('document_id'))
          render json: standard_error(:document_not_found, 'Document not found'),
            status: 401
          return
        end
        # read the document
        pages = nil
        begin
          if doc.size < 1048576 # MOOSE WARNING: store a constant for reasonable byte size cutoff somewhere
            pages = Policy.read_pdf(StringIO.new(doc.download))
          else
            tmp = Tempfile.new(encoding: 'ascii-8bit')
            tmp.write(doc.download)
            pages = Policy.read_pdf(tmp)
            tmp.unlink
          end
        rescue
          pages = nil
        end
        # return the document
        ## MOOSE WARNING: render something!!!
        render json: {
          document_url: document.service_url
        }, status: 200
      end
      
      
      def sign_document
        # find and validate the access token
        token = ::AccessToken.from_urlparam(params[:token])
        if token.nil? || token.access_type != 'user_document_signature'
          render json: standard_error(:document_not_found, 'Document not found'),
            status: 401
          return
        end
        # get the document
        policy = ::Policy.where(id: token.access_data&.[]('policy_id')).take
        document = policy&.documents&.where(id: token.access_data&.[]('document_id'))&.take
        if policy.nil? || document.nil? || !policy.unsigned_documents.include?(token.access_data&.[]('document_id'))
          render json: standard_error(:document_not_found, 'Document not found'),
            status: 401
          return
        end
        # 
        
      end
    
    
    
    end
  end
end
