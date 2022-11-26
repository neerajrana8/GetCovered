# == Schema Information
#
# Table name: stripe_charges
#
#  id                 :bigint           not null, primary key
#  processed          :boolean          default(FALSE), not null
#  invoice_aware      :boolean          default(FALSE), not null
#  status             :integer          default("processing"), not null
#  status_changed_at  :datetime
#  amount             :integer          not null
#  amount_refunded    :integer          default(0), not null
#  source             :string
#  customer_stripe_id :string
#  description        :string
#  metadata           :jsonb
#  stripe_id          :string
#  error_info         :string
#  client_error       :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  invoice_id         :bigint           not null
#  archived_charge_id :bigint
#
# StripeCharge model
# file: app/models/stripe_charge.rb

class StripeCharge < ApplicationRecord
  include DirtyTransactionTracker

  attr_accessor :callbacks_disabled

  belongs_to :invoice
  
  has_many :stripe_refunds
  has_many :stripe_disputes
  
  after_create :attempt_payment,
    unless: Proc.new{|sc| sc.callbacks_disabled }
  before_save :set_status_changed_at,
    if: Proc.new{|sc| sc.will_save_change_to_attribute?('status') && !sc.callbacks_disabled }
  after_commit :process,
    if: Proc.new{|sc| !sc.processed && sc.status != 'processing' && sc.saved_change_to_attribute_within_transaction?('status') && !sc.callbacks_disabled }
  
  enum status: {
    processing: 0, # must stay 0, it's the DB default
    pending: 1,
    succeeded: 2,
    failed: 3,
    errored: 4
  }
  
  def self.errorify(*linear_params, **keyword_params)
    {
      'linear' => linear_params,
      'keyword' => keyword_params
    }
  end
  
  def balance_transaction
    Stripe::Charge.retrieve(self.stripe_id).balance_transaction rescue nil
  end
  
  def displayable_error
    self.client_error.blank? ? nil : I18n.t(*(self.client_error['linear'] || []), **(self.client_error['keyword'] || {}))
  end
  
  def process
    self.with_lock do
      if !self.processed
        self.invoice.process_stripe_charge(self)
      end
    end
  end
  
  
  def attempt_payment
    return false if self.status != 'processing'
    # determine the source type
    source_type = if self.amount == 0
      :null_payment
    elsif !self.source.nil? && self.source.start_with?('src_', 'card_', 'ba_')
      :source
    elsif !self.source.nil? && (self.source.first(4) == 'tok_' || self.source.first(4) == 'btok')
      :token
    else
      :hellbeast
    end
    # handle non-source source types
    customer_stripe_id_to_use = self.customer_stripe_id
    case source_type
      when :source
        # do nothing; we will proceed after the switch statement
      when :hellbeast
        return self.update(
          status: 'failed',
          error_info: "Source '#{self.source}' is not a valid Stripe source or token",
          client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
        )
      when :null_payment
        return self.update(status: 'succeeded')
      when :token
        token = nil
        begin
          token = Stripe::Token.retrieve(self.source)
        rescue Stripe::StripeError => e
          return self.update(
            status: 'failed',
            error_info: "Unable to retrieve token '#{self.source}'. Stripe error: #{e.message}",
            client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
          )
        end
        if token[token['type']].nil?
          return self.update(
            status: 'failed',
            error_info: "Stripe returned token of type '#{token['type']}', but with no such hash key",
            client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
          )
        elsif token[token['type']]['id'].nil?
          return self.update(
            status: 'failed',
            error_info: "Stripe returned token with null source id",
            client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
          )
        end
        customer_stripe_id_to_use = nil
        # We should say self.source = token[token['type']]['id'], but this will NOT work. It needs to be attached to the customer before calling Stripe::Charge.create on it.
        # Therefore we will continue with the naked token and use it without a customer so it works.
        # MOOSE WARNING: Ideally this should be improved.
      else
        return self.update(
          status: 'failed',
          error_info: "Source had invalid type '#{source_type || 'nil'}'",
          client_error: ::StripeCharge.errorify('stripe_charge_model.invalid_stripe_source')
        )
    end
    # try to create the stripe charge
    stripe_charge = nil
    begin
      stripe_charge = Stripe::Charge.create({
        amount: self.amount,
        currency: 'usd',
        customer: customer_stripe_id_to_use,
        source: self.source,
        description: self.description,
        metadata: (self.metadata || {}).merge({ stripe_charge_id: self.id })
      }.compact)
    rescue Stripe::StripeError => e
      # try to extract info
      charge_id = nil
      error_data = e.respond_to?(:response) ? e.response&.data&.[](:error) : nil
      charge_id = error_data[:charge] unless error_data.class != ::Hash
      return self.update(
        status: 'failed',
        error_info: "Stripe charge creation failed with error: #{e.message}",
        client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_error')
      )
    end
    # handle completed charge
    if stripe_charge.nil?
      return self.update(
        status: 'failed',
        error_info: "Stripe charge creation threw no error but returned nil",
        client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_error')
      )
    elsif !stripe_charge.respond_to?('[]')
      return self.update(
        status: 'errored',
        error_info: "Stripe charge creation succeeded, but resulting object did not support square bracket operator",
        client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_mystery')
      )
    end
    case stripe_charge['status']
      when 'failed'
        return self.update(
          status: 'failed',
          stripe_id: stripe_charge['id'],
          error_info: "#{stripe_charge['failure_message'] || "Stripe charged failed with no failure_message"}",
          client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_rejection', code: "#{stripe_charge['failure_code'] || 'unknown reason'}")
        )
      when 'succeeded'
        return self.update(
          status: 'succeeded',
          stripe_id: stripe_charge['id']
        )
      when 'pending'
        return self.update(
          status: 'pending',
          stripe_id: stripe_charge['id']
        )
    end
    return self.update(
      status: 'errored',
      stripe_id: stripe_charge['id'],
      error_info: "Stripe charge creation succeeded, but resulting object did not have a known status (status was '#{stripe_charge['status']}')",
      client_error: ::StripeCharge.errorify('stripe_charge_model.payment_processor_mystery')
    )
  end
  
  private
  
  
    def set_status_changed_at
      self.status_changed_at = Time.current
    end
  
  
end
