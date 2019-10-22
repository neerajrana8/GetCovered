# Earnings Report Concern
# file: app/models/concerns/earnings_report.rb

module EarningsReport
  extend ActiveSupport::Concern

  def earnings_report
	  report_time = Time.now
	  report_start = report_time.midnight
	  report_end = report_time.end_of_day
	  
	  invoices_for_totals = invoices.complete.where(status_changed: report_start..report_end)
	  
    report = {
      invoice_available_count: invoices.available.count,
      invoice_completed_count: invoices_for_totals.count,
      invoice_missed_count: invoices.missed.where(status_changed: report_start..report_end).count,
      invoice_disputed_count: nil,
      invoice_refunded_count: nil,
      invoice_agency_subtotal: invoices_for_totals.inject(0) { |total, inv| total += inv.agency_subtotal },
      invoice_agency_total: invoices_for_totals.inject(0) { |total, inv| total += inv.agency_total },
      invoice_agency_net: invoices_for_totals.inject(0) { |total, inv| total += inv.agency_net },
      invoice_house_subtotal: invoices_for_totals.inject(0) { |total, inv| total += inv.house_subtotal },
      invoice_house_total: invoices_for_totals.inject(0) { |total, inv| total += inv.house_total },
      invoice_account_total: invoices_for_totals.inject(0) { |total, inv| total += inv.account_total },
      invoice_carrier_total: invoices_for_totals.inject(0) { |total, inv| total += inv.carrier_total },
      invoice_subtotal: invoices_for_totals.inject(0) { |total, inv| total += inv.subtotal },
      invoice_total: invoices_for_totals.inject(0) { |total, inv| total += inv.total }
    }
    
    return(report)
  end
end
