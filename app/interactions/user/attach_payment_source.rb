class User
  class AttachPaymentSource < ActiveInteraction::Base
    object :user
    string :token, default: nil
    boolean :make_default, default: true

    delegate :email, :profile, :stripe_id, :payment_profiles, :invoices, :policies, to: :user

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
              payer: user
            )

            if make_default
              user.current_payment_method = token_data.bank_account.status == 'verified' ? 'ach_verified' : 'ach_unverified'
              payment_profile.set_default
            end

          when 'card'
            customer.sources.create(source: token_data.id)
            customer.default_source = token_data.card.id if make_default
            customer.save

            payment_profile = PaymentProfile.create(
              source_id: Rails.env.to_sym == :awsdev ? 'tok_visa' : token_data.card.id, # Dirty hack upon request from the front-end team
              source_type: 'card',
              fingerprint: token_data.card.fingerprint,
              payer: user,
              card: token_data.card
            )

            if make_default
              user.current_payment_method = 'card'
              payment_profile.set_default
            end
          end

          return true if user.save && make_default
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
        if stripe_id.nil?
          policy_user = PolicyUser.find_by(user_id: user.id)
          policy = Policy.find_by(id: policy_user&.policy_id)
          customer = Stripe::Customer.create(
            email: email,
            metadata: {
              first_name: profile.first_name,
              last_name: profile.last_name,
              email: email,
              phone: profile&.contact_phone,
              agency: policy&.agency&.title,
              # product: policy&.product_type&.title
              product: policy&.policy_type&.title
            }
          )

          if user.update_columns(stripe_id: customer.id)
            customer
          else
            errors.merge!(user.errors)
            false
          end
        else
          Stripe::Customer.retrieve(stripe_id)
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
        user.current_payment_method = (account_verification_status ? 'ach_verified' : 'ach_unverified')
        stored_method.set_default
      when 'card'
        user.current_payment_method = 'card'
        stored_method.set_default
      end
    end

    def stored_method
      unless PaymentProfile.source_types.keys.any?(token_data.type)
        errors.add(:stripe_token_data_type, 'does not handle')
        return false
      end

      @stored_method ||= user.payment_profiles.find_by(source_type: token_data.type,
                                                       fingerprint: token_data[token_data.type].fingerprint)
    end
  end
end
