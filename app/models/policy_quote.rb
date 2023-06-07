# frozen_string_literal: true

# == Schema Information
#
# Table name: policy_quotes
#
#  id                    :bigint           not null, primary key
#  reference             :string
#  external_reference    :string
#  status                :integer          default("awaiting_estimate")
#  status_updated_on     :datetime
#  policy_application_id :bigint
#  agency_id             :bigint
#  account_id            :bigint
#  policy_id             :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  est_premium           :integer
#  external_id           :string
#  policy_group_quote_id :bigint
#  carrier_payment_data  :jsonb
#
##
# =Policy Quote Model
# file: +app/models/policy_quote.rb+

class PolicyQuote < ApplicationRecord
  # Concerns
  include CarrierPensioPolicyQuote
  include CarrierQbePolicyQuote
  include CarrierCrumPolicyQuote
  include CarrierMsiPolicyQuote
  include CarrierDcPolicyQuote

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

  has_many :commission_items, through: :policy_premium

  has_many_attached :documents

  accepts_nested_attributes_for :policy_premium

  enum status: { awaiting_estimate: 0, estimated: 1, quoted: 2,
                 quote_failed: 3, accepted: 4, declined: 5,
                 abandoned: 6, expired: 7, error: 8 }
  
  def primary_user
    self.policy_application.primary_user
  end

  def mark_successful
    policy_application.update status: 'quoted' if update status: 'quoted'
  end

  def mark_failure(error_message = nil, internal_error_message = nil)
    policy_application.update(status: 'quote_failed', error_message: error_message, internal_error_message: internal_error_message) if update status: 'quote_failed'
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
      { error: I18n.t('policy_quote_model.no_policy_for_qbe') }
    when 'crum'
      crum_bind
    when 'msi'
      msi_bind
    when 'dc'
      dc_bind
    else
      { error: I18n.t('policy_quote_model.error_with_policy_bund') }
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
      quote_attempt[:message] = I18n.t('policy_quote_model.quote_ineligible')
    else
      self.set_qbe_external_reference if policy_application.carrier.id == 1

      if !(update(status: "accepted") && start_billing())
        logger.error "Policy quote errors: #{self.errors.to_json}\nQuote attempt: #{quote_attempt}"
        quote_attempt[:message] = I18n.t('policy_quote_model.quote_billing_failed')
      else
        bind_request = self.send(*([quote_attempt[:bind_method]] + (bind_params.class == ::Array ? bind_params : [bind_params])))

        policy_number = nil
        policy_status = nil
        policy_signable_documents = nil
        
        if bind_request[:error]
          logger.error "Bind Failure; Message: #{bind_request[:message]}"
          quote_attempt[:message] = (bind_request[:client_message] || I18n.t('policy_quote_model.unable_to_bind_policy'))
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
            policy_signable_documents = bind_request[:data][:signable_documents] || nil
          end


          policy = build_policy(
            branding_profile_id: policy_application.branding_profile_id,
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
            (policy_signable_documents || []).each do |doc|
              doc.update(referent: policy)
            end
            
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
            if update(policy: policy) &&
               policy_application.update(policy: policy, status: "accepted") &&
               policy_premium.update(policy: policy)

              PolicyQuoteStartBillingJob.perform_later(policy: policy, issue: quote_attempt[:issue_method], queued_by: "PolicyQuote #{ self.id }")
              policy_type_identifier = policy_application.policy_type_id == 5 ? "Rental Guarantee" : "Policy"
              policy_msg = policy_application.policy_type_id == 5 ? I18n.t('policy_quote_model.rent_guarantee_has_been_accepted') : I18n.t('policy_quote_model.policy_has_been_accepted')
              quote_attempt[:message] = "##{ policy.number } #{ policy_msg }"
              quote_attempt[:success] = true

              LeadEvents::UpdateLeadStatus.run!(policy_application: policy_application)
              policy.run_postbind_hooks
            else
              # If self.policy, policy_application.policy or
              # policy_premium.policy cannot be set correctly
              logger.error policy.errors.to_json
              logger.error policy_application.errors.to_json
              logger.error policy_premium.errors.to_json
              logger.error self.errors.to_json
              quote_attempt[:message] = I18n.t('policy_quote_model.error_attaching_policy')
              update status: 'error'
            end
          else
            logger.error policy.errors.to_json
            quote_attempt[:message] = I18n.t('policy_quote_model.unable_to_save_policy')
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
        { error: I18n.t('policy_quote_model.no_build_coverages_for_qbe') }
      when 'crum'
        { error: I18n.t('policy_quote_model.no_build_coverages_for_crum') }
      when 'pensio'
        { error: I18n.t('policy_quote_model.no_build_coverages_for_pensio') }
      when 'msi'
        msi_build_coverages
      when 'dc'
        dc_build_coverages
      else
        { error: I18n.t('policy_quote_model.error_with_build_coverages') }
    end
  end

  def start_billing

    billing_started = false

    if policy.nil? &&
       policy_premium.total > 0 &&
       status == "accepted"
       
      policy_premium.policy_premium_item_commissions.update_all(status: 'active')

      invoices.external.update_all(status: 'managed_externally')
      invoices.internal.order("due_date").each_with_index do |invoice, index|
        invoice.update status: index == 0 ? "available" : "upcoming"
      end

      to_charge = invoices.internal.order("due_date").first
      if to_charge.nil?
        #policy.update(billing_status: "CURRENT") # there is no policy yet...
        return true
      end
      charge_invoice = to_charge.pay(stripe_source: :default)
      logger.error "Charge invoice error: #{charge_invoice.to_json}" unless charge_invoice[:success]
      if charge_invoice[:success] == true
        #policy.update(billing_status: "CURRENT")
        return true
      else
        #policy.update(billing_status: "ERROR")
        policy_premium.policy_premium_item_commissions.update_all(status: 'quoted')
        invoices.internal.update_all(status: 'quoted')
      end
    end

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
  def invoice_complete(invoice)
    unless self.policy.nil?
      if self.policy.BEHIND? || self.policy.REJECTED?
        self.policy.update_columns(billing_status: 'RESCINDED') unless self.policy.invoices.map{|inv| inv.status }.include?('missed')
      else
        self.policy.update_columns(billing_status: 'CURRENT')
      end
    end
    # Mailer?
  end

  # to be invoked by Invoice, not directly; an invoice payment attempt was missed
  #(either a job invoked this on/after the due date, or a payment attempt failed after the due date, in which case payment_failed and then payment_missed will be invoked by the invoice)
  def invoice_missed(invoice)
    unless self.policy.nil?
      self.policy.update_columns(billing_status: 'BEHIND', billing_behind_since: Time.current.to_date) unless self.policy.billing_status == 'BEHIND'
    end
    # Mailer?
  end
  
  def effective_moment
    self.effective_date.beginning_of_day
  end
  
  def expiration_moment
    self.expiration_date.end_of_day
  end
  
  def generate_invoices_for_term(renewal = false, refresh = false)
    # flee if renewal is true (unsupported right now)
    # if renewal
    #   app "============================================================"
    #   return {
    #     internal: "Invoice generation for policy renewals is not yet supported!",
    #     external: "policy_quote.cannot_gen_invoices_for_renewal"
    #   }
    # end
    # prepare
    invoices.destroy_all if refresh
    # get line items (format: { collector: { policy_premium_payment_term: [line_item,...] } }), with PPPTs in order
    line_items = self.policy_premium.policy_premium_items.map{|ppi| { ppi: ppi, line_items: ppi.generate_line_items } }
    failed_fellow = line_items.find{|li| li[:line_items].class == ::String }
    if failed_fellow
      return {
        internal: "Failed to generate line items for PolicyPremiumItem #{failed_fellow[:ppi].id}; received error: #{failed_fellow[:line_items]}",
        external: "policy_quote.line_item_gen_failed"
      }
    end
    line_items = line_items.group_by{|li| li[:ppi].collector }
                           .transform_values do |li_arr|
                            li_arr.map{|li| li[:line_items] }.flatten
                                  .group_by{|li| li.chargeable.policy_premium_payment_term }
                                  .sort_by{|k,v| k }.to_h
                           end
    # create invoices
    dat_problemo = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      invoices = line_items.map do |collector, by_pppt|
        index = -1
        [
          collector,
          by_pppt.map do |pppt, line_item_array|
            index += 1
            available_date = pppt.invoice_available_date_override || (index == 0 ? Time.current.to_date : pppt.first_moment.beginning_of_day - 1.day - self.available_period) # MOOSE WARNING: model must support .available_period
            due_date = pppt.invoice_due_date_override || (index == 0 ? (renewal ? pppt.first_moment.end_of_day : Time.current.to_date + 1.day) : pppt.first_moment.beginning_of_day - 1.day)
            #TODO: Thats  also can create duplicate invoices emails by change status in callbacks - NEED TO CHECK
            created = ::Invoice.create(
              available_date: available_date,
              due_date: due_date,
              external: !(collector.nil? || (collector.respond_to?(:master_agency) && collector.master_agency)),
              status: "quoted",
              invoiceable: self,
              payer: self.primary_user,
              collector: collector,
              line_items: line_item_array
            )
            unless created.id
              dat_problemo = {
                internal: "Failed to generate invoice for collector #{collector.class.name} ##{collector.id} and PolicyPremiumPaymentTerm #{pppt.id}; errors were #{created.errors.to_h}",
                external: "policy_quote_model.invoice_gen_failed"
              }
              raise ActiveRecord::Rollback
            end
            next created
          end
        ]
      end.to_h
    end
    # all done
    return dat_problemo
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
