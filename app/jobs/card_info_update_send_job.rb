class CardInfoUpdateSendJob < ApplicationJob
  queue_as :default

  def perform(charge)
    user = charge.invoice.payer
    if user.is_a? User
      policy = charge.invoice.invoiceable

      CardInfoUpdateMailer.please_update_card_info(email: user.email, name: user.profile.full_name, policy: policy).deliver
    end
  end
end
