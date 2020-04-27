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
        data: { policy_number: pensio_generate_number(::Policy) }
      }
    end

    def pensio_bind_group
      {
        error: false,
        message: nil,
        data: { policy_group_number: pensio_generate_number(PolicyGroup) }
      }
    end

    def pensio_generate_number(model)
      number = nil

      loop do
        number = "PENSIOUSA#{rand(36**12).to_s(36).upcase}"

        break unless model.exists?(number: number)
      end

      return number unless number.nil?
    end
  end
end
