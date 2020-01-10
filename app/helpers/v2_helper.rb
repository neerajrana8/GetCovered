module V2Helper
  def link_to_document_preview(document)
    rails_representation_url(
      document.variant(resize: '300x200').processed,
      host: Rails.application.credentials[:uri][ENV['RAILS_ENV'].to_sym][:api]
    )
  end

  def link_to_document(document)
    rails_blob_url(
      document,
      host: Rails.application.credentials[:uri][ENV['RAILS_ENV'].to_sym][:api]
    )
  end
end
