module CarrierQBE
  class AccordFileMailer < ApplicationMailer

    def failed_records(failed)
      @failed = failed
      mail(subject: 'Failed records from QBE', to: "systememails@getcovered.io")
    end
  end
end