module Qbe
  module Renewal
    # Qbe::Renewal::Issuer
    class Issuer < ApplicationService

      attr_accessor :policy
      attr_accessor :premium

      def initialize(policy, premium)
        @policy = policy
        @premium = premium
      end

      def call
        renewal_attempt = false

        if @policy.update renewal_status: 'PREPARED'
          renewal_count = (@policy.renew_count || 0) + 1
          renewed_on = @policy.expiration_date + 1.day
          new_expiration_date = @policy.expiration_date + 1.year
          if @policy.update renew_count: renewal_count, last_renewed_on: renewed_on,
                            expiration_date: new_expiration_date, renewal_status: 'PENDING'
            begin
              @policy.invoices.where(status: 'quoted').update_all(status: 'upcoming')
              @policy.invoices.where(status: 'upcoming', due_date: @policy.created_at..DateTime.current.to_date)
                     .update_all(status: 'available')

              relevant_premium = @policy.policy_premiums.order(created_at: :desc).first
              unless relevant_premium.nil?
                Qbe::Finance::PremiumUpdater.call(relevant_premium, @premium, policy.last_renewed_on)
              end

              @policy.invoices.where(status: 'missed', due_date: @policy.last_renewed_on..DateTime.current.to_date)
                     .find_each { |i| i.update status: 'available' }

              available_invoices = @policy.invoices.where(status: 'available').order(due_date: :asc)
              first_invoice = available_invoices.first
              invoices_to_merge = available_invoices.where.not(id: first_invoice.id)

              unless invoices_to_merge.nil?
                invoices_to_merge.each do |invoice|
                  invoice.line_items.each do |line_item|
                    line_item.update invoice: first_invoice
                  end
                  invoice.destroy if invoice.line_items.count == 0
                end
              end

              first_invoice.send("mark_line_items_priced_in")
              first_invoice.save

              payment_attempt = first_invoice.pay(stripe_source: :default, allow_missed: true)
              if payment_attempt[:success]
                renewal_attempt = true if @policy.update renewal_status: 'RENEWED'
              else
                mark_failed()
              end
            rescue Exception => e
              mark_failed()
            end
          else
            mark_failed()
          end
        else
          mark_failed()
        end

        return renewal_attempt
      end

      private

      def mark_failed
        @policy.update renewal_status: 'FAILED'
      end

    end
  end
end