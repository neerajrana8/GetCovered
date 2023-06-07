module CarrierQBE
  class AccordFileMailer < ApplicationMailer

    def failed_records(failed)
      @failed = failed
      mail(subject: 'Failed records from QBE', to: "dylan@getcovered.io")
    end

    def premium_update_failed(policy)

    end

  end
end