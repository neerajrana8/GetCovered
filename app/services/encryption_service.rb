# frozen_string_literal: true

class EncryptionService

  def self.decrypt(text)
    key = Base64.decode64(Rails.application.credentials.encryption_key)
    crypt = ActiveSupport::MessageEncryptor.new(key)
    crypt.decrypt_and_verify text
  end

  def self.encrypt(text)
    key = Base64.decode64(Rails.application.credentials.encryption_key)
    crypt = ActiveSupport::MessageEncryptor.new(key)
    crypt.encrypt_and_sign text
  end
end
