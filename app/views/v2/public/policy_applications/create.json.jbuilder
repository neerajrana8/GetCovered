json.id @application.id

json.quote do
  json.id @quote.id
  json.status @quote.status
  json.premium do
    json.partial! "v2/public/policy_premia/policy_premium_show_fields.json.jbuilder",
      policy_premium: @premium || @quote.policy_premium
  end unless @premium || @quote.policy_premium.nil?
end
json.user do
  json.id @application.primary_user.id
  json.stripe_id @application.primary_user.stripe_id
end
json.invoices do
  json.array! @quote.invoices.order('due_date ASC') do |invoice|
    json.partial! "v2/public/invoices/invoice_index_fields.json.jbuilder",
      invoice: invoice
  end
end
    
unless !instance_variable_defined?(:@extra_fields) || @extra_fields.blank?
  json.merge!(@extra_fields)
end
