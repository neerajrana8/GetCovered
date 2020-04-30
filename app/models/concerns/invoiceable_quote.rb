#
# InvoiceableQuote Concern
# file: app/models/concerns/invoiceable_quote.rb

module InvoiceableQuote
  extend ActiveSupport::Concern



  # WARNING:
  #  the model this concern is used on must provide status_updated_on and available_period,
  #  and must have an entry in this concern's private methods
  #  get_policy_premium_invoice_information and get_policy_application_invoice_information
	def generate_invoices_for_term(renewal = false, refresh = false)
    errors = {}
    
    unless renewal
	    
	    invoices.destroy_all if refresh
	    
      # get info from policy premium
      premium_data = get_policy_premium_invoice_information
      if premium_data.nil?
        puts "Invoiceable Quote cannot generate invoices without an associated policy premium"
        errors[:policy_premium] = "cannot be blank"
        return errors
      end
      
	  	if premium_data[:total] > 0 && 
		  	 status == "quoted" && 
		  	 invoices.count == 0
        
        # get info from policy application
        billing_plan = get_policy_application_invoice_information
        if billing_plan.nil?
          puts "Invoiceable Quote cannot generate invoices without an associated policy application"
          errors[:policy_application] = "cannot be blank"
          return errors
        end
        
        # calculate sum of weights (should be 100, but just in case it's 33+33+33 or something)
        payment_weight_total = billing_plan[:billing_schedule].inject(0){|sum,p| sum + p }.to_d
        payment_weight_total = 100.to_d if payment_weight_total <= 0 # this can never happen unless someone fills new_business with 0s invalidly, but you can't be too careful
        
        # setup
        roundables = [:deposit_fees, :amortized_fees, :base, :special_premium, :taxes]                              # fields on PolicyPremium to have rounding errors fixed
        refundabilities = { base: 'prorated_refund', special_premium: 'prorated_refund', taxes: 'prorated_refund' } # fields that can be refunded on cancellation (values are LineItem#refundability values)
        line_item_names = { base: "Premium" }                                                                       # fields to rename on the invoice
        line_item_categories = { base: "base_premium", special_premium: "special_premium", taxes: "taxes", deposit_fees: "deposit_fees", amortized_fees: "amortized_fees" }
        
        # calculate invoice charges
        to_charge = billing_plan[:billing_schedule].map.with_index do |payment, index|
          {
            due_date:        index == 0 ? status_updated_on : billing_plan[:effective_date] + index.months,
            term_first_date: billing_plan[:effective_date] + index.months,
            deposit_fees:    (index == 0 ? premium_data[:deposit_fees] : 0),
            amortized_fees:  (premium_data[:amortized_fees] * payment / payment_weight_total).floor,
            base:            (premium_data[:base] * payment / payment_weight_total).floor,
            special_premium: (premium_data[:special_premium] * payment / payment_weight_total).floor,
            taxes:           (premium_data[:taxes] * payment / payment_weight_total).floor
          }
        end.map{|tc| tc.merge({ total: roundables.inject(0){|sum,r| sum + tc[r] } }) }.select{|tc| tc[:total] > 0 }
        # set term_last_dates
        (0...(to_charge.length - 1)).each do |charge_index|
          to_charge[charge_index][:term_last_date] = to_charge[charge_index + 1][:term_first_date] - 1.day
        end
        to_charge.last[:term_last_date] = billing_plan[:effective_date] + 12.months - 1.day
        # add any rounding errors to the first charge
        roundables.each do |roundable|
          to_charge[0][roundable] += premium_data[roundable] - to_charge.inject(0){|sum,tc| sum + tc[roundable] }
        end
        to_charge[0][:total] = roundables.inject(0){|sum,r| sum + to_charge[0][r] }
        # ensure total matches premium_data[:total]... this should never be necessary
        unaccounted_error = premium_data[:total] - to_charge.inject(0){|sum,tc| sum + tc[:total] }
        to_charge[0][:additional_fees] = unaccounted_error unless unaccounted_error <= 0 # this should always be 0
        # create invoices
        begin
          ActiveRecord::Base.transaction do
            to_charge.each.with_index do |tc, tci|
              invoices.create!({
                due_date:         tc[:due_date],
                available_date:   tc[:due_date] - available_period,
                term_first_date:  tc[:term_first_date],
                term_last_date:   tc[:term_last_date],
                payee:            billing_plan[:payee],
                status:           "quoted",
                
                total:            tc[:total], # subtotal & total are calculated automatically from line items, but if we pass one manually validations will fail if it doesn't match the calculation
                line_items_attributes: (roundables + [:additional_fees]).map do |roundable|
                  {
                    title: line_item_names[roundable] || roundable.to_s.titleize,
                    price: tc[roundable] || 0,
                    refundability: refundabilities[roundable] || 'no_refund',
                    category: line_item_categories[roundable] || 'uncategorized'
                  }
                end.select{|lia| !lia.nil? && lia[:price] > 0 }
              })
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          puts e.to_s
          errors = e.record.errors.to_h
        rescue StandardError => e
          puts "Error during invoice creation! #{e}"
          errors[:server] = "encountered an error during invoice generation #{e}"
        rescue
          puts "Unknown error during invoice creation!"
          errors[:server] = "encountered an error during invoice creation"
        end
				
		  end
	  else
	  	# Set up Renewal Invoice Generation
	  end
    
    return errors
    
  end


  private
  
  
    def get_policy_premium_invoice_information
      if respond_to?(:policy_premium)
        {
          total: policy_premium.total,
          deposit_fees: policy_premium.deposit_fees,
          amortized_fees: policy_premium.amortized_fees,
          base: policy_premium.base,
          special_premium: policy_premium.special_premium,
          taxes: policy_premium.taxes
        }
      elsif respond_to?(:policy_group_premium)
        {
          total: policy_group_premium.total,
          deposit_fees: policy_group_premium.deposit_fees,
          amortized_fees: policy_group_premium.amortized_fees,
          base: policy_group_premium.base,
          special_premium: policy_group_premium.special_premium,
          taxes: policy_group_premium.taxes
        }
      else
        nil
      end
    end
    
  
    def get_policy_application_invoice_information
      if respond_to?(:policy_application)
        {
          billing_schedule: policy_application.billing_strategy.new_business['payments'],
          effective_date: policy_application.effective_date,
          payee: policy_application.primary_user
        }
      elsif respond_to?(:policy_application_group)
        {
          billing_schedule: policy_application_group.billing_strategy.new_business['payments'],
          effective_date: policy_application_group.effective_date,
          payee: policy_application_group.account
        }
      else
        nil
      end
    end
    

end
