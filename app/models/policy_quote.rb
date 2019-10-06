##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
  include CarrierQbePolicyQuote, ElasticsearchSearchable
  # include ElasticsearchSearchable

  before_save :set_status_updated_on,
  	if: Proc.new { |quote| quote.status_changed? }
  before_validation :set_reference,
  	if: Proc.new { |quote| quote.reference.nil? }

  belongs_to :policy_application, optional: true

  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true

	has_many :events,
	    as: :eventable

	has_many :policy_rates
	has_many :insurable_rates,
		through: :policy_rates

	has_one :policy_premium

	accepts_nested_attributes_for :policy_premium

  enum status: { available: 0, expired: 1, accepted: 2,
	  						 declined: 3, abandoned: 4 }

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end

  def available_period
    7.days
  end

  def start_billing
    return false unless policy.in_system?

    billing_started = false

    if !policy.nil? && policy_premium.total > 0 && status == "accepted"
      policy.agency.billing_strategies.each do |strategy|
        strategy.new_business['payments'].each_with_index do |payment, index|
          amount = policy_premium.total * (payment.to_f / 100)
          next if amount == 0

          # Due date is today for the first invoice. After that it is due date
          # after effective date of the policy
          due_date = index == 0 ? status_updated_on : policy.effective_date + index.months
          invoice = policy.invoices.new do |inv|
            inv.due_date        = due_date
            inv.available_date  = due_date + available_period
            inv.user            = policy.primary_user
            inv.amount          = amount
          end
          invoice.save
        end
        charge_invoice = policy.invoices.first.pay(allow_upcoming: true)

        if charge_invoice[:success] == true
          return true
        end
      end
    end
    billing_status
  end


  # Build Invoices from Schedule
  #

  def build_invoices_from_strategy
    build_complete = false

    error_hash = {}

    if policy && premium.to_f > 0
      policy.agency.billing_strategies.each do |strategy|
        # This calculates due_date
        due_date = status_updated_on + 12 / strategy.new_business['payments_per_term']
        invoice = policy.invoices.new(
          due_date: due_date,
          available_date: available_date
        )

        policy_rates.each do |r|
          price = r.premium / strategy.new_business['payments']

          line_item = invoice.line_items.new(title: r.title, price: price.floor)
        end

        sub_total = invoice.line_items.inject(0) { |result, line_item| result += line_item.price }

        if sub_total < inv['amount'].to_i
          adjustment = invoice.line_items.new(title: "#{ self.carrier.title } Adjustment", price: (inv['amount'] - sub_total))
        end

        tmp_total = invoice.line_items.inject(0) { |result, line_item| result += line_item.price }

        invoice.subtotal = tmp_total
        invoice.total = tmp_total

        if invoice.save()
          inv['invoice_id'] = invoice.id
        else
          pp invoice.errors
          error_hash[inv['index'].to_s] = true
        end

      end
    end
  end

  private
    def set_status_updated_on
	    self.status_updated_on = Time.now
	  end

    def set_reference
	    return_status = false

	    if reference.nil?

	      loop do
	        self.reference = "#{account.call_sign}-#{rand(36**12).to_s(36).upcase}"
	        return_status = true

	        break unless PolicyQuote.exists?(:reference => self.reference)
	      end
	    end

	    return return_status
	  end

end
