class BillPastDueInvoicesJob < ApplicationJob
  queue_as :default
  before_perform :set_agencies

  def perform(*args)
    @agencies.each do |agency|
      interval_counts = []
      agency.settings['billing_retry_max'].times { |retry_count| interval_counts << (retry_count + 1) * agency.settings['billing_retry_interval'] }      

      policies = agency.policies
                       .in_system?(true)
                       .current
                       .unpaid
                       .where(billing_enabled: true)

      policies.each do |policy|

        unpaid_invoices = policy.invoices.unpaid.where("due_date < ?", Time.now.to_date)

        unpaid_invoices.each do |invoice|

          charge_attempts = invoice.charges.failed.count
          last_attempt = invoice.charges.order(:created_at).last

          if charge_attempts < agency.settings['billing_retry_max']
            
            interval_counts.each do |day_count|
              invoice.pay if (Time.current.to_date - day_count.days) == last_attempt.created_at.to_date 
            end           
              
          end
        end
      end
    end
  end

  private

    def set_agencies
      @agencies = Agency.enabled.all # Invoice.includes(:policy).where(policies: { billing_enabled: true }, due_date: Time.current.to_date).available
    end
end
