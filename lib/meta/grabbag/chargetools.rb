







def get_missing_charges(start_time = nil)
  constraints = {}
  constraints[:created] = { gte: (start_time.class == ::Date ? start_time.midnight : start_time).to_i } unless start_time.nil?
  # get all charges for this user
  response = Stripe::Charge.list(constraints)
  retrieved = response["data"]
  while response["has_more"]
    response = Stripe::Charge.list({ starting_after: retrieved.last.id }.merge(constraints))
    retrieved.concat(response["data"])
  end
  # filter out present ones
  present_ids = Charge.where(stripe_id: retrieved.map{|r| r.id }).order(:stripe_id).group(:stripe_id).pluck(:stripe_id)
  return retrieved.select{|r| !present_ids.include?(r.id) }
end
# def get_missing_charges(start_time = nil);   constraints = {};   constraints[:created] = { gte: (start_time.class == ::Date ? start_time.midnight : start_time).to_i } unless start_time.nil?;   response = Stripe::Charge.list(constraints);   retrieved = response["data"];   while response["has_more"];     response = Stripe::Charge.list({ starting_after: retrieved.last.id }.merge(constraints));     retrieved.concat(response["data"]);   end;   present_ids = Charge.where(stripe_id: retrieved.map{|r| r.id }).order(:stripe_id).group(:stripe_id).pluck(:stripe_id);   return retrieved.select{|r| !present_ids.include?(r.id) }; end


def get_valid_charge_hash(charges)
  grouped = charges.group_by{|c| c.description.split("Invoice #")[1] }
  valid = grouped.select{|k,v| !Invoice.where(number: k).take.nil? }
  valid.transform_keys!{|k| Invoice.where(number: k).take }
  return valid
end




def insert_charges(stripe_charge_hash)
  # go wild
  to_insert = []
  stripe_charge_hash.each do |invoice, charges|
    charges.each do |charge|
      to_insert.push(
        '(' + (
          {
            status: ::Charge.statuses[charge.status],
            status_information: (charge.failure_message.blank? ? "NULL" : "'" + "Payment processor reported failure: #{charge.failure_message || 'unknown error'} (code #{charge.failure_code || 'null'})".gsub("'", "\\\\\'") + "'"),
            refund_status: ::Charge.refund_statuses['not_refunded'],
            payment_method: ::Charge.payment_methods[charge.source["object"] == "card" ? "card" : charge.source["object"] == "bank_account" ? "bank_account" : "unknown"],
            amount_returned_via_dispute: 0,
            amount_refunded: 0,
            amount_lost_to_disputes: 0,
            amount_in_queued_refunds: 0,
            dispute_count: 0,
            stripe_id: "'#{charge.id}'",
            invoice_id: invoice.id,
            created_at: "'#{DateTime.strptime(charge.created.to_s, '%s').to_s(:db)}'",
            updated_at: "'#{Time.current.to_s(:db)}'",
            amount: charge.amount,
            invoice_update_failed: 'FALSE',
            invoice_update_error_call: 'NULL',
            invoice_update_error_record: 'NULL',
            invoice_update_error_hash: 'NULL'
          }.values.join(",")
        ) + ')'
      )
    end
  end
  cols =  'status,status_information,refund_status,payment_method,amount_returned_via_dispute,'
  cols += 'amount_refunded,amount_lost_to_disputes,amount_in_queued_refunds,dispute_count,'
  cols += 'stripe_id,invoice_id,created_at,updated_at,amount,invoice_update_failed,'
  cols += 'invoice_update_error_call,invoice_update_error_record,invoice_update_error_hash'
  sql = "INSERT INTO charges (#{cols}) VALUES #{to_insert.join(", ")}"
  ActiveRecord::Base.connection.execute(sql)
end
















