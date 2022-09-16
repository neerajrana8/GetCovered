module CarrierQBE
  class GenerateandSendCancellationListJob < ApplicationJob

    # Queue: Default
    queue_as :default

    def perform(*args)
      today = Time.current.to_date
      if [1,2,3,4,5].include?(today.wday)
        qbe_service = QbeService.new(:action => 'sendCancellationList')
        message = qbe_service.build_request
        if Rails.env == production
          ActionMailer::Base.mail(from: 'no-reply@getcovered.io',
                                  to: ['dylan@getcoveredllc.com', 'jared@getcoveredllc.com'],
                                  subject: "PEX/REX Sample XML",
                                  body: message).deliver_now()
        end
      end
    end

  end
end