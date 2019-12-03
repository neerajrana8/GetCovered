# This class is used for encrypting strings in databases
class StringEncrypterSerializer
  class << self
    def load(value)
      decrypt(value) unless value.nil?
    end

    def dump(value)
      encrypt(value) unless value.nil?
    end

    private

    def encrypt(value)
      value = value.to_s unless value.is_a? String

      len = ActiveSupport::MessageEncryptor.key_len
      salt = SecureRandom.hex len
      key = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
      crypt = ActiveSupport::MessageEncryptor.new key
      encrypted_data = crypt.encrypt_and_sign value
      "#{salt}#{encrypted_data}"
    end

    def decrypt(value)
      len = ActiveSupport::MessageEncryptor.key_len
      salt = value[0..len * 2 - 1]
      data = value[len * 2..-1]
      key = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
      crypt = ActiveSupport::MessageEncryptor.new key
      crypt.decrypt_and_verify data
    end
  end
end
