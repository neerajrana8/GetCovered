module CarrierQBE
  class GenerateandSendCancellationListJob < ApplicationJob

    # Queue: Default
    queue_as :default

    def perform(*args)
      today = Time.current.to_date
      if [1,2,3,4,5].include?(today.wday)
        qbe_service = QbeService.new(:action => 'sendCancellationList')
        message = qbe_service.build_request
        if Rails.env == "production"
          if ActionMailer::Base.mail(from: 'no-reply@getcovered.io',
                                     to: ['dylan@getcovered.io', 'jared@getcovered.io'],
                                     subject: "PEX/REX Sample XML",
                                     body: message).deliver_now()
            Policy.current.where(carrier_id: 1, policy_type_id: 1, billing_status: 'RESCINDED').find_each do |policy|
              policy.update billing_status: 'CURRENT'
            end
          end
        end
      end
    end

  end
end