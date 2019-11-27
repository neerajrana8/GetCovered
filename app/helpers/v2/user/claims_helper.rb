module V2
  module User
    module ClaimsHelper
      def link_to_preview(document)
        rails_representation_url(
          document.variant(resize: '300x200').processed,
          host: Rails.application.credentials[:uri][Rails.application.credentials.rails_env.to_sym][:api]
        )
      end

      def link_to_document(document)
        rails_blob_url(
          document,
          host: Rails.application.credentials[:uri][Rails.application.credentials.rails_env.to_sym][:api]
        )
      end
    end
  end
end
