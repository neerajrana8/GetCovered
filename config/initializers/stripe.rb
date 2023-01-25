require "stripe"
Stripe.api_key = Rails.application
											.credentials
											.stripe[ENV.fetch("RAILS_ENV").to_sym][:secret_key]

Rails.configuration.stripe = {
	:publishable_key => Rails.application
													 .credentials
													 .stripe[ENV.fetch("RAILS_ENV").to_sym][:publishable_key],
	:secret_key      => Rails.application
													 .credentials
													 .stripe[ENV.fetch("RAILS_ENV").to_sym][:secret_key]
}
