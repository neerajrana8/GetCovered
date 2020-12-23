class CardInfoUpdateSendJob < ApplicationJob
  queue_as :default

  def perform(charge)
    user = charge.invoice.payer
    if user.is_a? User
      policy = charge.invoice.invoiceable.policy

      CardInfoUpdateMailer.please_update_card_info(user: user, policy: policy).deliver
    end
  end
end
