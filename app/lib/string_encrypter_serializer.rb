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
      cipher = OpenSSL::Cipher.new('AES-256-CBC').encrypt
      cipher.key = cipher_key
      s = cipher.update(value) + cipher.final

      s.unpack1('H*')
    end

    def decrypt(value)
      cipher = OpenSSL::Cipher.new('AES-256-CBC').decrypt
      cipher.key = cipher_key
      s = [value].pack('H*')

      cipher.update(s) + cipher.final
    end

    # generate 32 byte key from the encryption_key
    def cipher_key
      Digest::MD5.hexdigest Rails.application.credentials.encryption_key
    end
  end
end
