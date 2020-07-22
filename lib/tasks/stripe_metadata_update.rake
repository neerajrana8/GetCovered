require 'rake'

namespace :stripe_metadata_update do
  desc 'Update all customers stripe metadata'
  task move_payment_methods: :environment do
    Invoice.all.each do |invoice|
      user = User.find_by(id: invoice.payer.stripe_id)
        user = User&.find(invoice&.payer_id)
        user_name = user&.profile&.first_name
        user_last_name = user&.profile&.last_name
        contact_phone = user&.profile&.contact_phone
        policy_user = PolicyUser.find_by(user_id: user.id)
        policy = Policy.find_by(id: policy_user.policy_id)
        agency_title = policy&.agency&.title
        policy_title = policy&.policy_type&.title
        policy_number = policy&.number
        # Stripe::Charge.update()
        stripe_charge = Stripe::Charge.create({
          metadata: {
            first_name: user_name,
            last_name: user_last_name,
            phone: contact_phone,
            agency: agency_title,
            product: policy_title,
            policy_number: policy_number
          }
      end
    end
  end
end
