##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+
# frozen_string_literal: true

class PolicyQuote < ApplicationRecord
  # Concerns
  include CarrierPensioPolicyQuote
  include CarrierQbePolicyQuote
  include CarrierCrumPolicyQuote
  include CarrierMsiPolicyQuote
  include CarrierDcPolicyQuote
  include ElasticsearchSearchable
  include InvoiceableQuote

  before_save :set_status_updated_on,
    if: Proc.new { |quote| quote.status_changed? }
  before_validation :set_reference,
    if: Proc.new { |quote| quote.reference.nil? }

  belongs_to :policy_application, optional: true

  belongs_to :agency, optional: true
  belongs_to :account, optional: true
  belongs_to :policy, optional: true
  belongs_to :policy_group_quote, optional: true

  has_many :events, as: :eventable

  has_many :policy_rates
  has_many :insurable_rates, through: :policy_rates

  has_one :policy_premium

  has_many :invoices, as: :invoiceable

  has_many_attached :documents

  accepts_nested_attributes_for :policy_premium

  enum status: { awaiting_estimate: 0, estimated: 1, quoted: 2,
                 quote_failed: 3, accepted: 4, declined: 5,
                 abandoned: 6, expired: 7, error: 8 }

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :reference, type: :text, analyzer: 'english'
      indexes :external_reference, type: :text, analyzer: 'english'
    end
  end

  def mark_successful
    policy_application.update status: 'quoted' if update status: 'quoted'
  end

  def mark_failure
    policy_application.update status: 'quote_failed' if update status: 'quote_failed'
  end

  def available_period
    7.days
  end

  def bind_policy
    case policy_application.carrier.integration_designation
    when 'qbe'
      set_qbe_external_reference
      qbe_bind
    when 'qbe_specialty'
      { error: 'No policy bind for QBE Specialty' }
    when 'crum'
      crum_bind
    when 'msi'
      msi_bind
    when 'dc'
      dc_bind
    else
      { error: 'Error happened with policy bind' }
    end
  end

  def accept(bind_params: [])

    quote_attempt = {
      success: false,
      message: nil,
      bind_method: "#{ policy_application.carrier.integration_designation }_bind",
      issue_method: "#{ policy_application.carrier.integration_designation }_issue_policy"
    }

    if !(quoted? || error?)
      quote_attempt[:message] = "Quote ineligible for acceptance"
    else
      self.set_qbe_external_reference if policy_application.carrier.id == 1

      if !(update(status: "accepted") && start_billing())
        logger.error "Policy quote errors: #{self.errors.to_json}\nQuote attempt: #{quote_attempt}"
        quote_attempt[:message] = "Quote billing failed, unable to write policy"
      else
        bind_request = self.send(*([quote_attempt[:bind_method]] + (bind_params.class == ::Array ? bind_params : [bind_params])))

        policy_number = nil
        policy_status = nil
        policy_documents = nil
        
        if bind_request[:error]
          logger.error "Bind Failure; Message: #{bind_request[:message]}"
          quote_attempt[:message] = "Unable to bind policy"
        else
          if policy_application.policy_type.title == "Residential"
            policy_number = bind_request[:data][:policy_number]
            policy_status = bind_request[:data][:status] == "WARNING" ? "BOUND_WITH_WARNING" : "BOUND"
          elsif policy_application.policy_type.title == "Commercial"
            policy_number = external_reference
            policy_status = "BOUND"
          elsif policy_application.policy_type.title == "Rent Guarantee"
            policy_number = bind_request[:data][:policy_number]
            policy_status = "BOUND"
          elsif policy_application.policy_type.title == "Security Deposit Replacement"
            policy_number = bind_request[:data][:policy_number]
            policy_status = "BOUND"
            policy_documents = bind_request[:data][:documents] || nil
          end


          policy = build_policy(
            number: policy_number,
            status: policy_status,
            billing_status: "CURRENT",
            effective_date: policy_application.effective_date,
            expiration_date: policy_application.expiration_date,
            auto_renew: policy_application.auto_renew,
            auto_pay: policy_application.auto_pay,
            policy_in_system: true,
            system_purchased: true,
            billing_enabled: true,
            serviceable: policy_application.carrier.syncable,
            policy_type: policy_application.policy_type,
            agency: policy_application.agency,
            account: policy_application.account,
            carrier: policy_application.carrier
          )

          if policy.save
            # Add documents to policy, if applicable
            needing_signature = []
            (policy_documents || []).each do |doc|
              # set up document
              doc_id = nil
              case doc[:source]
                when ::ActiveStorage::Attachment
                  # move from PQ to P
                  doc[:source].update(record_type: "Policy", record_id: policy.id)
                  doc_id = doc[:source].id
                else
                  logger.error "Invalid document source type '#{doc[:source].class.name}'"
                  next
              end
              # mark for signing if needed
              needing_signature.push(doc_id) if doc[:needs_signature]
            end
            policy.update_columns(unsigned_documents: needing_signature) unless needing_signature.blank?
            
            # reload policy
            policy.reload
            
            # Add users to policy
            policy_application.policy_users
                              .each do |pu|
              pu.update policy: policy
              pu.user.convert_prospect_to_customer()
            end

            # Add insurables to policy
            policy_application.policy_insurables.update_all policy_id: policy.id

            # Add rates to policy
            policy_application.policy_rates.update_all policy_id: policy.id

            build_coverages() if policy_application.policy_type.title == "Residential"
            if update!(policy: policy) &&
               policy_application.update(policy: policy, status: "accepted") &&
               policy_premium.update(policy: policy)

              PolicyQuoteStartBillingJob.perform_later(policy: policy, issue: quote_attempt[:issue_method])
              policy_type_identifier = policy_application.policy_type_id == 5 ? "Rental Guarantee" : "Policy"
              quote_attempt[:message] = "#{ policy_type_identifier } ##{ policy.number }, has been accepted.  Please check your email for more information."
              quote_attempt[:success] = true

              LeadEvents::UpdateLeadStatus.run!(policy_application: policy_application)
            else
              # If self.policy, policy_application.policy or
              # policy_premium.policy cannot be set correctly
              logger.error policy.errors.to_json
              logger.error policy_application.errors.to_json
              logger.error policy_premium.errors.to_json
              logger.error self.errors.to_json
              quote_attempt[:message] = "Error attaching policy to system"
              update status: 'error'
            end
          else
            logger.error policy.errors.to_json
            quote_attempt[:message] = "Unable to save policy in system"
          end
        end
      end
    end

    return quote_attempt
  end

  def decline
    return_success = false
    if self.update(status: 'declined') && self.policy_application.update(status: "rejected")
      return_success = true
    end
    return return_success
  end

  def build_coverages()
    case policy_application.carrier.integration_designation
      when 'qbe'
        qbe_build_coverages
      when 'qbe_specialty' # WARNING: the following aren't really errors... but they also aren't checked anywhere, so it doesn't hurt to leave them for now
        { error: 'No build coverages for QBE Specialty' }
      when 'crum'
        { error: 'No build coverages for Crum' }
      when 'pensio'
        { error: 'No build coverages for Pensio' }
      when 'msi'
        msi_build_coverages
      when 'dc'
        dc_build_coverages
      else
        { error: 'Error happened with build coverages' }
    end
  end

  def start_billing

    billing_started = false

    if policy.nil? &&
       policy_premium.total > 0 &&
       status == "accepted"

      invoices.external.update_all(status: 'managed_externally')
      invoices.internal.order("due_date").each_with_index do |invoice, index|
        invoice.update status: index == 0 ? "available" : "upcoming"
      end

      to_charge = invoices.internal.order("due_date").first
      return true if to_charge.nil?
      charge_invoice = to_charge.pay(stripe_source: :default)
      logger.error "Charge invoice: #{charge_invoice.to_json}" unless charge_invoice[:success]
      if charge_invoice[:success] == true
        return true
      end
    end

#     if !policy.nil? && policy_premium.calculation_base > 0 && status == "accepted"
#
# 	    invoices.order("due_date").each_with_index do |invoice, index|
# 		  	invoice.update status: index == 0 ? "available" : "upcoming",
# 		  								 policy: policy
# 		  end
#
# 		  charge_invoice = invoices.order("due_date").first.pay(stripe_source: policy_application.primary_user().payment_profiles.first.source_id)
#
#       if charge_invoice[:success] == true
#         policy.update billing_status: "CURRENT"
#         return true
#       else
#         policy.update billing_status: "ERROR"
#       end
#
#     end

    billing_started

  end


  # to be invoked by Invoice, not directly; an invoice became disputed or its disputes were all resolved. count_change is 1 if an invoice became disputed, -1 if not
  def modify_disputed_invoice_count(count_change)
    return true if count_change == 0
    self.policy.with_lock do
      new_bdc = self.policy.billing_dispute_count + count_change
      if new_bdc < 0
        return false # this should never happen... WARNING: good place to put an error logger just in case?
      end
      self.policy.update_columns(
        billing_dispute_count: new_bdc,
        billing_dispute_status: new_bdc == 0 ? 'AWAITING_POSTDISPUTE_PROCESSING' : 'DISPUTED'
      )
    end unless self.policy.nil?
    return true
  end

  # to be invoked by Invoice, not directly; an invoice payment attempt was successful
  def payment_succeeded(invoice)
    unless self.policy.nil?
      if self.policy.BEHIND? || self.policy.REJECTED?
        self.policy.update_columns(billing_status: 'RESCINDED') unless self.policy.invoices.map{|inv| inv.status }.include?('missed')
      else
        self.policy.update_columns(billing_status: 'CURRENT')
      end
    end
    # Mailer?
  end

  # to be invoked by Invoice, not directly; an invoice payment attempt failed (keep in mind it might not actually have been due yet, and that invoice.status will not yet have been changed to available/missed when this is called!)
  def payment_failed(invoice)
    # Mailer? (will run whenever a charge fails, including before due date or on auto-pay attempts after due date)
  end

  # to be invoked by Invoice, not directly; an invoice payment attempt was missed
  #(either a job invoked this on/after the due date, or a payment attempt failed after the due date, in which case payment_failed and then payment_missed will be invoked by the invoice)
  def payment_missed(invoice)
    unless self.policy.nil?
      self.policy.update_columns(billing_status: 'BEHIND', billing_behind_since: Time.current.to_date) unless self.policy.billing_status == 'BEHIND'
    end
    # Mailer?
  end

  # to be invoked by Invoice, not directly; an invoice received payment or underwent a refund
  def invoice_collected_changed(invoice, amount_collected, old_amount_collected)
    self.policy_premium.update_unearned_premium
  end

  private
    def set_status_updated_on
      self.status_updated_on = Time.now
    end

    def set_reference
      return_status = false

      if reference.nil?

        loop do
          parent_entity = account.nil? ? agency : account
          self.reference = "#{parent_entity.call_sign}-#{rand(36**12).to_s(36).upcase}"
          return_status = true

          break unless PolicyQuote.exists?(:reference => self.reference)
        end
      end

      return return_status
    end
end
