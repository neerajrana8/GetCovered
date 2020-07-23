require 'rake'

namespace :stripe_metadata do
  desc 'Update all customers stripe metadata'
  task update_stripe_meta: :environment do
    Charge.pluck(:stripe_id, :invoice_id).each do |un_id|
      Invoice.find_by(id: un_id[1].to_i) do |invoice|
        user = User&.find(invoice&.payer_id)
        user_name = user&.profile&.first_name
        user_last_name = user&.profile&.last_name
        contact_phone = user&.profile&.contact_phone
        policy_user = PolicyUser.find_by(user_id: user.id)
        policy = Policy.find_by(id: policy_user.policy_id)
        agency_title = policy&.agency&.title
        policy_title = policy&.policy_type&.title
        policy_number = policy&.number
        Stripe::Charge.update(
          un_id[0].to_s,
          {metadata: {
            first_name: user_name,
            last_name: user_last_name,
            phone: contact_phone,
            agency: agency_title,
            product: policy_title,
            policy_number: policy_number
          }})
      end
    end
  end
end
