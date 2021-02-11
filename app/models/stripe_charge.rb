# StripeCharge model
# file: app/models/stripe_charge.rb

class StripeCharge < ApplicationRecord

  include ChargeType

  belongs_to :invoice,
    optional: true
  
  has_many :stripe_refunds
  has_many :stripe_disputes
  
  enum status: ['processing', 'pending', 'succeeded', 'failed', 'mysterious']
  
  def self.errorify(*linear_params, **keyword_params)
    {
      'linear' => linear_params,
      'keyword' => keyword_params
    }
  end
  
  def self.create_charge(amount, source, customer_id, description: nil, metadata: nil)
    # determine the source type
    source_type = if amount == 0
      :null_payment
    elsif !source.nil? && source.start_with?('src_', 'card_', 'ba_')
      :source
    elsif !source.nil? && (source.first(4) == 'tok_' || source.first(4) == 'btok')
      :token
    else
      :hellbeast
    end
    # handle non-source source types
    case source_type
      when :source
        # do nothing; we will proceed after the switch statement
      when :hellbeast
        return ::StripeCharge.create(amount: amount, source: source, external_id: nil,
          status: 'failed',
          error_info: "Source '#{source}' is not a valid Stripe source or token",
          client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
        )
      when :null_payment
        return ::StripeCharge.create(amount: amount, source: source, external_id: nil,
          status: 'succeeded'
        )
      when :token
        token = nil
        begin
          token = Stripe::Token.retrieve(source)
        rescue Stripe::StripeError => e
          return ::StripeCharge.create(amount: amount, source: source, external_id: nil,
            status: 'failed',
            error_info: "Unable to retrieve token '#{source}'. Stripe error: #{e.message}",
            client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
          )
        end
        if token[token['type']].nil?
          return ::StripeCharge.create(amount: amount, source: source, external_id: nil,
            status: 'failed',
            error_info: "Stripe returned token of type '#{token['type']}', but with no such hash key",
            client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
          )
        elsif token[token['type']]['id'].nil?
          return ::StripeCharge.create(amount: amount, source: source, external_id: nil,
            status: 'failed',
            error_info: "Stripe returned token with null source id",
            client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
          )
        end
        customer_stripe_id = nil
        # We should say stripe_source = token[token['type']]['id'], but this will NOT work. It needs to be attached to the customer before calling Stripe::Charge.create on it.
        # Therefore we will continue with the naked token and use it without a customer so it works.
        # MOOSE WARNING: Ideally this should be improved.
      else
        return ::StripeCharge.create(amount: amount, source: source, external_id: nil,
          status: 'failed',
          error_info: "Source had invalid type '#{source_type || 'nil'}'",
          client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
        )
    end
    # pre-create the charge to be returned (so it has an id)
    to_return = ::StripeCharge.create(amount: amount, source: source, external_id: nil,
      status: 'processing'
    )
    # try to create the stripe charge
    stripe_charge = nil
    begin
      stripe_charge = Stripe::Charge.create({
        amount: amount,
        currency: 'usd',
        customer: customer_stripe_id,
        source: stripe_source,
        description: description,
        metadata: (metadata || {}).merge({ stripe_charge_id: to_return.id, metadata_format: 1 })
      }.compact)
    rescue Stripe::StripeError => e
      # try to extract info
      charge_id = nil
      error_data = e.respond_to?(:response) ? e.response&.data&.[](:error) : nil
      charge_id = error_data[:charge] unless error_data.class != ::Hash
      to_return.update(status: 'failed',
        error_info: "Stripe charge creation failed with error: #{e.message}",
        client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_error')
      )
      return to_return
    end
    # handle completed charge
    if stripe_charge.nil?
      to_return.update(status: 'failed',
        error_info: "Stripe charge creation threw no error but returned nil",
        client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_error')
      )
      return to_return
    elsif !stripe_charge.respond_to?('[]')
      to_return.update(status: 'mysterious',
        error_info: "Stripe charge creation succeeded, but resulting object did not support square bracket operator",
        client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_mystery')
      )
      return to_return
    end
    case stripe_charge['status']
      when 'failed'
        to_return.update(status: 'failed',
          external_id: stripe_charge['id'],
          error_info: "#{stripe_charge['failure_message'] || "Stripe charged failed with no failure_message"}",
          client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_rejection', code: "#{stripe_charge['failure_code'] || 'unknown reason'}")
        )
        return to_return
      when 'succeeded'
        to_return.update(status: 'succeeded',
          external_id: stripe_charge['id']
        )
        return to_return
      when 'pending'
        to_return.update(status: 'pending',
          external_id: stripe_charge['id']
        )
        return to_return
    end
    to_return.update(status: 'mysterious',
      external_id: stripe_charge['id'],
      error_info: "Stripe charge creation succeeded, but resulting object did not have a known status (status was '#{stripe_charge['status']}')",
      client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_mystery')
    )
    return to_return
  end
  
  
end
