# =Pensio Policy Quote Functions Concern
# file: +app/models/concerns/carrier_pensio_policy_quote.rb+

module CarrierPensioPolicyQuote
  extend ActiveSupport::Concern

  included do

    # Generate Quote
    #

    def pensio_bind
      {
        error: false,
        message: nil,
        data: { policy_number: generate_policy_number }
      }
    end

    def generate_policy_number
      policy_number = nil

      loop do
        policy_number = "PENSIOUSA#{rand(36**12).to_s(36).upcase}"

        break unless Policy.exists?(number: policy_number)
      end

      return policy_number unless policy_number.nil?
    end
  end
end
