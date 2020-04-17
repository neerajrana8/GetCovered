#
# InvoiceableQuote Concern
# file: app/models/concerns/invoiceable_quote.rb

module InvoiceableQuote
  extend ActiveSupport::Concern


=begin
#vars used:
self
  status_updated_on
  available_period
policy_premium
  deposit_fees
  amortized_fees
  calculation_base
  total_fees
  total
policy_application
  billing_strategy.new_business['payments']
  effective_date
  primary_user
=end


	def generate_invoices_for_term(renewal = false, refresh = false)
    invoices_generated = false
    
    unless renewal
	    
	    invoices.destroy_all if refresh
	    
	  	if policy_premium.calculation_base > 0 && 
		  	 status == "quoted" && 
		  	 invoices.count == 0
        
        # get info from policy application
        billing_plan = get_policy_application_invoice_information
        if billing_plan.nil?
          puts "Invoiceable Quote cannot generate invoices without an associated policy application"
          invoices_generated = false
          return invoices_generated
        end
        
        # calculate sum of weights (should be 100, but just in case it's 33+33+33 or something)
        payment_weight_total = billing_plan[:billing_schedule].inject(0){|sum,p| sum + p }.to_d
        payment_weight_total = 100.to_d if payment_weight_total <= 0 # this can never happen unless someone fills new_business with 0s invalidly, but you can't be too careful
        
        # calculate invoice charges
        to_charge = billing_plan[:billing_schedule].map.with_index do |payment, index|
          {
            due_date: index == 0 ? status_updated_on : billing_plan[:effective_date] + index.months,
            term_first_date: billing_plan[:effective_date] + index.months,
            fees: (policy_premium.amortized_fees * payment / payment_weight_total).floor + (index == 0 ? policy_premium.deposit_fees : 0),
            total: (policy_premium.calculation_base * payment / payment_weight_total).floor + (index == 0 ? policy_premium.deposit_fees : 0)
          }
        end.select{|tc| tc[:total] > 0 }
        # set term_last_dates
        (0...(to_charge.length - 1)).each do |charge_index|
          to_charge[charge_index][:term_last_date] = to_charge[charge_index + 1][:term_first_date] - 1.day
        end
        to_charge.last[:term_last_date] = billing_plan[:effective_date] + 12.months - 1.day
        # add any rounding errors to the first charge
        to_charge[0][:fees] += policy_premium.total_fees - to_charge.inject(0){|sum,tc| sum + tc[:fees] }
        to_charge[0][:total] += policy_premium.total - to_charge.inject(0){|sum,tc| sum + tc[:total] }
        
        # create invoices
        begin
          ActiveRecord::Base.transaction do
            to_charge.each.with_index do |tc, tci|
              invoices.create!({
                due_date:       tc[:due_date],
                available_date: tc[:due_date] - available_period,
                term_first_date: tc[:term_first_date],
                term_last_date: tc[:term_last_date],
                user:           billing_plan[:primary_user],
                status:         "quoted",
                
                total:          tc[:total], # subtotal & total are calculated automatically from line items, but if we pass one manually validations will fail if it doesn't match the calculation
                line_items_attributes: [
                  tci == 0 ? {
                    title: "Deposit Fees",
                    price: policy_premium.deposit_fees,
                    refundability: 'no_refund'
                  } : nil,
                  {
                    title: "Amortized Fees",
                    price: tc[:fees] - (tci == 0 ? policy_premium.deposit_fees : 0),
                    refundability: 'no_refund'
                  },
                  {
                    title: "Premium Payment",
                    price: tc[:total] - tc[:fees],
                    refundability: 'prorated_refund'
                  }
                ].select{|lia| !lia.nil? && lia[:amount] > 0 }
              })
            end
            invoices_generated = true
          end
        rescue ActiveRecord::RecordInvalid => e
          puts e.to_s
        rescue
          puts "Unknown error during invoice creation"
        end
				
		  end
	  else
	  	# Set up Renewal Invoice Generation
	  end
    
    return invoices_generated
    
  end


  private
  
  
    def get_policy_application_invoice_information
      if respond_to?(:policy_application)
        {
          billing_schedule: policy_application.billing_strategy.new_business['payments'],
          effective_date: policy_application.effective_date,
          primary_user: policy_application.primary_user
        }
      # MOOSE WARNING: fill this out once PolicyApplicationGroup has the appropriate fields
      #elsif respond_to?(:policy_application_group)
      #  {
      #  }
      else
        nil
      end
    end

end
