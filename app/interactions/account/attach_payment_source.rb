class Account
  class AttachPaymentSource < ActiveInteraction::Base
    object :account
    string :token, default: nil
    boolean :make_default, default: true

    delegate :owner, :payment_profile_stripe_id, :payment_profiles, :invoices, to: :account

    def execute
      begin
        if token.present? && customer != false && stored_method != false
          case token_data.type
          when 'bank_account'
            customer.sources.create(source: token_data.id)
            customer.default_source = token_data.bank_account.id if make_default
            customer.save

            payment_profile = PaymentProfile.create(
              source_id: token_data.bank_account.id,
              source_type: 'bank_account',
              fingerprint: token_data.bank_account.fingerprint,
              verified: token_data.bank_account.status == 'verified',
              payer: account
            )

            if make_default
              account.current_payment_method = token_data.bank_account.status == 'verified' ? 'ach_verified' : 'ach_unverified'
              payment_profile.set_default
            end

          when 'card'
            customer.sources.create(source: token_data.id)
            customer.default_source = token_data.card.id if make_default
            customer.save

            payment_profile = PaymentProfile.create(
              source_id: Rails.env.to_sym == :awsdev ? 'tok_visa' : token_data.card.id, # Dirty hack upon request from the front-end team,
              source_type: 'card',
              fingerprint: token_data.card.fingerprint,
              payer: account,
              card: token_data.card
            )

            if make_default
              account.current_payment_method = 'card'
              payment_profile.set_default
            end
          end

          if account.save
            return true
          end
        end
      rescue Stripe::APIConnectionError => _
        errors.add(:payment_method, 'Network Error')
      rescue Stripe::StripeError => error
        Rails.logger.error "AttachPaymentSource StripeError: #{error.to_s}. Token: #{token}"
        errors.add(:payment_method, error.message)
      end
      false
    end

    private

    def customer
      @customer ||=
        if payment_profile_stripe_id.nil?
          customer = Stripe::Customer.create(
            email: owner.email,
            metadata: {
              first_name: owner&.profile&.first_name,
              last_name: owner&.profile&.last_name,
              email: owner.email,
              phone: owner&.profile&.contact_phone,
              agency: account&.agency&.title
            }
          )

          if account.update_columns(payment_profile_stripe_id: customer.id)
            customer
          else
            errors.merge!(account.errors)
            false
          end
        else
          Stripe::Customer.retrieve(payment_profile_stripe_id)
        end
    end

    def token_data
      @token_data ||= Stripe::Token.retrieve(token)
    end

    def set_default_payment
      customer.default_source = stored_method.source_id
      customer.save
      case token_data.type
      when 'bank_account'
        reactivated_bank_account = customer.sources.retrieve(stored_method.source_id)
        account_verification_status = reactivated_bank_account.status == 'verified'
        stored_method.update(verified: account_verification_status)
        account.current_payment_method = (account_verification_status ? 'ach_verified' : 'ach_unverified')
        stored_method.set_default
      when 'card'
        account.current_payment_method = 'card'
        stored_method.set_default
      end
    end

    def stored_method
      unless PaymentProfile.source_types.keys.any?(token_data.type)
        errors.add(:stripe_token_data_type, 'does not handle')
        return false
      end

      @stored_method ||= account.payment_profiles.find_by(source_type: token_data.type,
                                                       fingerprint: token_data[token_data.type].fingerprint)
    end
  end
end
