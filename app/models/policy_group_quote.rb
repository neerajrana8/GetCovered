class PolicyGroupQuote < ApplicationRecord
  PENSIO_BILLING_STRATEGY_ID = 23

  belongs_to :policy_application_group
  has_one :policy_group_premium, dependent: :destroy
  has_many :policy_applications, through: :policy_application_group
  has_many :policy_quotes
  has_many :policy_premiums, through: :policy_quotes
  has_many :invoices, as: :invoiceable

  before_save :set_status_updated_on, if: Proc.new { |quote| quote.status_changed? }

  enum status: { awaiting_estimate: 0, estimated: 1, quoted: 2,
                 quote_failed: 3, accepted: 4, declined: 5,
                 abandoned: 6, expired: 7, error: 8 }

  def calculate_premium
    self.policy_group_premium = PolicyGroupPremium.create(billing_strategy_id: PENSIO_BILLING_STRATEGY_ID)
    policy_group_premium.calculate_total
    update(status: :estimated)
  end

  def accept
    start_billing
  end

  def generate_invoices(refresh = false)
    invoices_generated = false

    invoices.destroy_all if refresh

    if policy_group_premium.calculation_base > 0 && status == 'quoted' && invoices.count.zero?
      # calculate sum of weights (should be 100, but just in case it's 33+33+33 or something)
      payment_weight_total = policy_application_group.billing_strategy.new_business['payments'].inject(0) { |sum, p| sum + p }.to_d
      payment_weight_total = 100.to_d if payment_weight_total <= 0 # this can never happen unless someone fills new_business with 0s invalidly, but you can't be too careful

      # calculate invoice charges
      to_charge = policy_application_group.billing_strategy.new_business['payments'].map.with_index do |payment, index|
        {
          due_date: index.zero? ? status_updated_on : policy_application_group.effective_date + index.months,
          fees: (policy_group_premium.amortized_fees * payment / payment_weight_total).floor + (index == 0 ? policy_group_premium.deposit_fees : 0),
          total: (policy_group_premium.calculation_base * payment / payment_weight_total).floor + (index == 0 ? policy_group_premium.deposit_fees : 0)
        }
      end
      to_charge = to_charge.select { |tc| tc[:total] > 0 }
      
      # add any rounding errors to the first charge
      to_charge[0][:fees] += policy_group_premium.total_fees - to_charge.inject(0) { |sum, tc| sum + tc[:fees] }
      to_charge[0][:total] += policy_group_premium.total - to_charge.inject(0) { |sum, tc| sum + tc[:total] }

      # create invoices
      begin
        ActiveRecord::Base.transaction do
          to_charge.each do |tc|
            invoices.create!(
              due_date: tc[:due_date],
              available_date: tc[:due_date] - available_period,
              subtotal: tc[:total] - tc[:fees],
              total: tc[:total],
              status: 'quoted'
            )
          end
          invoices_generated = true
        end
      rescue ActiveRecord::RecordInvalid => e
        puts e.to_s
      rescue StandardError
        puts 'Unknown error during invoice creation'
      end
    end

    invoices_generated
  end

  def available_period
    7.days
  end

  def start_billing
    billing_started = false

    if policy.nil? && policy_group_premium.calculation_base.positive? && status == 'accepted'

      invoices.order('due_date').each_with_index do |invoice, index|
        invoice.update status: index.zero? ? 'available' : 'upcoming'
      end

      charge_invoice = invoices.order('due_date').first.pay(stripe_source: policy_application.primary_user.payment_profiles.first.source_id)

      return true if charge_invoice[:success] == true
    end
    billing_started
  end

  private

  def set_status_updated_on
    self.status_updated_on = Time.now
  end
end
