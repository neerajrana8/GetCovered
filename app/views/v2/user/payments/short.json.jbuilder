json.array! @payments,
  partial: 'v2/user/payments/payment_short_full.json.jbuilder',
  as: :payment
