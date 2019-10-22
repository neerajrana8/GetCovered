require "stripe"
Stripe.api_key = Rails.application
											.credentials
											.stripe[Rails.application.credentials.rails_env.to_sym][:secret_key]

Rails.configuration.stripe = {
  :publishable_key => Rails.application
													 .credentials
													 .stripe[Rails.application.credentials.rails_env.to_sym][:publishable_key],
  :secret_key      => Rails.application
													 .credentials
													 .stripe[Rails.application.credentials.rails_env.to_sym][:secret_key]
}