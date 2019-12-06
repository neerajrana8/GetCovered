require 'rake'

namespace :data_migration do
  desc 'Move data from user.payment_methods to payment_profiles'
  task move_payment_methods: :environment do
    User.all.each do |user|
      next unless user.payment_methods['by_id'].present?

      params =
        user.payment_methods['by_id'].map do |_, data|
          { source_id: data['id'], source_type: data['type'], fingerprint: data['fingerprint'], user: user }
        end
      PaymentProfile.create(params)
      user.payment_profiles.find_by(source_id: user.payment_methods['default']).set_default
    end
  end
end
