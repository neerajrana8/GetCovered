class PolicyQuoteGetDocumentsJob < ApplicationJob
  queue_as :default

  def perform(quote: )
    return if quote.nil?
	    
    quote.get_document()
    quote.policy_application.policy_users.each do |pu|
      UserCoverageMailer.with(quote: quote, user: pu.user).commercial_quote().deliver if pu.user
    end
  end
end
